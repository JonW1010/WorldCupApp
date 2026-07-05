import SwiftUI

// MARK: - Filter

enum FilterOption: String, CaseIterable {
    case england     = "England"
    case active      = "Active Teams"
    case other       = "Other Teams"
    case goalscorers = "Goalscorers"
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var service = WorldCupService()
    @State private var filter: FilterOption = .england

    private var filteredMatches: [Match] {
        let active = service.activeTeams
        switch filter {
        case .england:
            return service.matches.filter {
                $0.team1 == "England" || $0.team2 == "England"
            }
        case .active:
            return service.matches.filter {
                $0.team1 != "England" && $0.team2 != "England" &&
                (active.contains($0.team1) || active.contains($0.team2))
            }
        case .other:
            return service.matches.filter {
                $0.team1 != "England" && $0.team2 != "England" &&
                !active.contains($0.team1) && !active.contains($0.team2)
            }
        case .goalscorers:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                Group {
                    if service.isLoading {
                        ProgressView("Loading results…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                    } else if let error = service.errorMessage {
                        ErrorView(message: error) {
                            Task { await service.fetchResults() }
                        }

                    } else if filter == .goalscorers {
                        goalscorersView

                    } else if filteredMatches.isEmpty {
                        ContentUnavailableView(
                            "No Results Yet",
                            systemImage: "soccerball",
                            description: Text("Results will appear here once matches are played.")
                        )

                    } else {
                        matchList(filteredMatches)
                    }
                }
            }
            .navigationTitle("FIFA World Cup 2026")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await service.fetchResults() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(service.isLoading)
                }
            }
        }
        .task { await service.fetchResults() }
    }

    private var topGoalscorers: [GoalscorerInfo] { service.topGoalscorers }

    @ViewBuilder private var goalscorersView: some View {
        if topGoalscorers.isEmpty {
            ContentUnavailableView(
                "No Goalscorers Yet",
                systemImage: "soccerball",
                description: Text("Goalscorer data will appear once matches are played.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(topGoalscorers.enumerated()), id: \.element.id) { index, scorer in
                        NavigationLink(destination: GoalscorerDetailView(scorer: scorer)) {
                            GoalscorerRow(rank: index + 1, scorer: scorer)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private func matchList(_ matches: [Match]) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    // Invisible anchor at the very top
                    Color.clear.frame(height: 0).id("top")

                    LazyVStack(spacing: 0) {
                        ForEach(matches) { match in
                            NavigationLink(destination: MatchDetailView(
                                match: match,
                                tournamentGoals: service.tournamentGoals
                            )) {
                                MatchRow(match: match)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .refreshable {
                    await service.fetchResults()
                }

                // Scroll-to-top button
                Button {
                    withAnimation { proxy.scrollTo("top", anchor: .top) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white, .blue)
                        .shadow(radius: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Match Row

struct MatchRow: View {
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Teams & score on one line each
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    teamLabel(match.team1, score: match.score1)
                    teamLabel(match.team2, score: match.score2)
                }
                Spacer()
                // Winner indicator
                if let s1 = match.score1, let s2 = match.score2 {
                    Image(systemName: s1 > s2 ? "arrow.up.circle.fill" :
                                      s2 > s1 ? "arrow.down.circle.fill" :
                                                "minus.circle.fill")
                        .foregroundStyle(s1 == s2 ? Color.secondary : Color.green)
                        .font(.title3)
                }
            }

            // Date · Round · Venue
            HStack(spacing: 8) {
                Label(formattedDate(match.date), systemImage: "calendar")
                if let round = match.round {
                    Text("·")
                    Text(round)
                }
                if let ground = match.ground {
                    Text("·")
                    Text(ground)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func teamLabel(_ name: String, score: Int?) -> some View {
        HStack {
            Text(name)
                .font(.headline)
            Spacer()
            if let score {
                Text("\(score)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 24, alignment: .trailing)
            }
        }
    }

    private func formattedDate(_ raw: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: raw) else { return raw }
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Match Detail View

struct MatchDetailView: View {
    let match: Match
    let tournamentGoals: [String: Int]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score header
                VStack(spacing: 8) {
                    HStack {
                        Text(match.team1)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Text(match.scoreDisplay)
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(match.team2)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if let round = match.round {
                        Text(round)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let ground = match.ground {
                        Label(ground, systemImage: "mappin.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Goal scorers
                HStack(alignment: .top, spacing: 16) {
                    goalColumn(goals: match.goals1 ?? [], label: match.team1)
                    Divider()
                    goalColumn(goals: match.goals2 ?? [], label: match.team2)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func goalColumn(goals: [Goal], label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)

            if goals.isEmpty {
                Text("No goals")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                ForEach(goals, id: \.name) { goal in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: goal.isPenalty ? "p.circle.fill" : "soccerball")
                                .font(.caption)
                                .foregroundStyle(goal.isPenalty ? .blue : .primary)
                            Text(goal.name)
                                .font(.subheadline.bold())
                        }
                        HStack(spacing: 8) {
                            if let min = goal.minute {
                                Text("\(min)'")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            let total = tournamentGoals[goal.name] ?? 1
                            Text("· \(total) goal\(total == 1 ? "" : "s") in tournament")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Failed to load results")
                .font(.title3.bold())
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Goalscorer Row

struct GoalscorerRow: View {
    let rank: Int
    let scorer: GoalscorerInfo

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(scorer.name)
                    .font(.headline)
                Text(scorer.country)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "soccerball")
                    .font(.caption)
                Text("\(scorer.goals)")
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Goalscorer Detail View

struct GoalscorerDetailView: View {
    let scorer: GoalscorerInfo

    @State private var wiki: WikiSummary?
    @State private var isLoadingWiki = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Profile photo
                Group {
                    if isLoadingWiki {
                        ProgressView()
                            .frame(width: 120, height: 120)
                    } else if let src = wiki?.thumbnail?.source, let url = URL(string: src) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                            .frame(width: 120, height: 120)
                    }
                }

                // Name · Country · Goals
                VStack(spacing: 6) {
                    Text(scorer.name)
                        .font(.title2.bold())
                    Label(scorer.country, systemImage: "flag.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(scorer.goals) goal\(scorer.goals == 1 ? "" : "s") in tournament")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }

                // Club team
                if let club = extractClub(from: wiki?.extract) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Club Team")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Label(club, systemImage: "shield.lefthalf.filled")
                            .font(.body.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Bio extract
                if let extract = wiki?.extract {
                    Text(extract)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(scorer.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadWiki() }
    }

    private func loadWiki() async {
        let slug = scorer.name
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? scorer.name

        if let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)"),
           let (data, _) = try? await URLSession.shared.data(from: url) {
            wiki = try? JSONDecoder().decode(WikiSummary.self, from: data)
        }
        isLoadingWiki = false
    }

    /// Parses the club team name from a Wikipedia extract's first sentence.
    private func extractClub(from text: String?) -> String? {
        guard let text else { return nil }
        let sentence = text.components(separatedBy: ". ").first ?? text
        // Pattern 1: "for [adj] [football] club [Club Name]"
        // Pattern 2: "for [Club Name] and the [Country] national"
        let patterns = [
            #"for (?:\w+ )*?club ([A-Z][^,.(]+?)(?= and | and$|\.|,|$)"#,
            #"for ([A-Z][^,.(]+?) and the \w+ national"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsStr = sentence as NSString
            let range = NSRange(location: 0, length: nsStr.length)
            if let match = regex.firstMatch(in: sentence, range: range),
               match.numberOfRanges > 1,
               let swiftRange = Range(match.range(at: 1), in: sentence) {
                let club = String(sentence[swiftRange]).trimmingCharacters(in: .whitespaces)
                if !club.isEmpty { return club }
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
