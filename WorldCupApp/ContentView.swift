import SwiftUI

// MARK: - Filter

enum FilterOption: String, CaseIterable {
    case england     = "England"
    case active      = "Active"
    case other       = "Others"
    case goalscorers = "Scorers"
    case bracket     = "Bracket"
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var service = WorldCupService()
    @State private var filter: FilterOption = .england

    private var filteredMatches: [Match] {
        let active = service.activeTeams
        switch filter {
        case .england:
            return service.allMatches
                .filter { $0.team1 == "England" || $0.team2 == "England" }
                .sorted { $0.date > $1.date }
        case .active:
            return service.allMatches
                .filter {
                    $0.team1 != "England" && $0.team2 != "England" &&
                    (active.contains($0.team1) || active.contains($0.team2))
                }
                .sorted { $0.date > $1.date }
        case .other:
            return service.matches.filter {
                $0.team1 != "England" && $0.team2 != "England" &&
                !active.contains($0.team1) && !active.contains($0.team2)
            }
        case .goalscorers:
            return []
        case .bracket:
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

                    } else if filter == .bracket {
                        BracketView(matches: service.knockoutMatches)

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
            Text("\(countryFlag(name)) \(name)")
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
                        Text("\(countryFlag(match.team1)) \(match.team1)")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Text(match.scoreDisplay)
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(.primary)
                        Text("\(countryFlag(match.team2)) \(match.team2)")
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
            Text("\(countryFlag(label)) \(label)")
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
                Text("\(countryFlag(scorer.country)) \(scorer.country)")
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
                    Text("\(countryFlag(scorer.country)) \(scorer.country)")
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

// MARK: - Bracket View

struct BracketView: View {
    let matches: [Match]

    private let cardW: CGFloat   = 152
    private let cardH: CGFloat   = 70
    private let hGap: CGFloat    = 40   // horizontal space between round columns
    private let baseSlot: CGFloat = 88  // cardH + vertical gap between cards in round 0

    // Knockout matches excluding third-place play-off
    private var rounds: [(name: String, matches: [Match])] {
        let main = matches.filter {
            let r = ($0.round ?? "").lowercased()
            return !r.contains("third") && !r.contains("3rd") &&
                   !(r.contains("play") && r.contains("off"))
        }
        let grouped = Dictionary(grouping: main) { $0.round ?? "Unknown" }
        return grouped
            .sorted { roundOrder($0.key) < roundOrder($1.key) }
            .map { (name: $0.key, matches: $0.value.sorted { $0.date < $1.date }) }
    }

    private func roundOrder(_ name: String) -> Int {
        let r = name.lowercased()
        if r.contains("round of 32") { return 0 }
        if r.contains("round of 16") { return 1 }
        if r.contains("quarter")     { return 2 }
        if r.contains("semi")        { return 3 }
        if r.contains("final")       { return 4 }
        return 9
    }

    private func shortRoundName(_ name: String) -> String {
        let r = name.lowercased()
        if r.contains("32")      { return "Round of 32" }
        if r.contains("16")      { return "Round of 16" }
        if r.contains("quarter") { return "Quarterfinals" }
        if r.contains("semi")    { return "Semifinals" }
        if r.contains("final")   { return "Final" }
        return name
    }

    private var baseCount: Int { rounds.first?.matches.count ?? 1 }

    private var canvasW: CGFloat { CGFloat(rounds.count) * (cardW + hGap) + hGap }
    private var canvasH: CGFloat { CGFloat(baseCount) * baseSlot + cardH + 28 }

    // X of left edge of round column ri
    private func xForRound(_ ri: Int) -> CGFloat {
        CGFloat(ri) * (cardW + hGap) + hGap / 2
    }

    // Y of top edge of match mi in round ri
    private func yForMatch(round ri: Int, match mi: Int) -> CGFloat {
        let mult   = pow(2.0, Double(ri))
        let offset = (mult - 1.0) / 2.0 * Double(baseSlot)
        let spacing = mult * Double(baseSlot)
        return CGFloat(offset + Double(mi) * spacing) + 28   // +28 for header
    }

    // Pre-compute bracket connector paths
    private var connectorPaths: [Path] {
        var paths: [Path] = []
        for ri in 0..<rounds.count - 1 {
            let count1 = rounds[ri].matches.count
            let count2 = rounds[ri + 1].matches.count
            let x1    = xForRound(ri)
            let x2    = xForRound(ri + 1)
            let midX  = x1 + cardW + hGap / 2

            var i = 0, ni = 0
            while i < count1 {
                guard ni < count2 else { break }

                let yA = yForMatch(round: ri, match: i) + cardH / 2

                if i + 1 < count1 {
                    // Pair: two matches → one next match
                    let yB = yForMatch(round: ri, match: i + 1) + cardH / 2
                    let yN = yForMatch(round: ri + 1, match: ni) + cardH / 2

                    var p = Path()
                    // Stub from match A → midX, then vertical bar down to match B level
                    p.move(to: CGPoint(x: x1 + cardW, y: yA))
                    p.addLine(to: CGPoint(x: midX, y: yA))
                    p.addLine(to: CGPoint(x: midX, y: yB))
                    // Stub from match B → midX (separate subpath so we don't double the vertical)
                    p.move(to: CGPoint(x: x1 + cardW, y: yB))
                    p.addLine(to: CGPoint(x: midX, y: yB))
                    // Connector from centre of vertical → left of next match
                    p.move(to: CGPoint(x: midX, y: (yA + yB) / 2))
                    p.addLine(to: CGPoint(x: x2, y: yN))
                    paths.append(p)
                    i += 2; ni += 1
                } else {
                    // Odd/bye: direct line
                    let yN = yForMatch(round: ri + 1, match: ni) + cardH / 2
                    var p = Path()
                    p.move(to: CGPoint(x: x1 + cardW, y: yA))
                    p.addLine(to: CGPoint(x: midX, y: yA))
                    p.addLine(to: CGPoint(x: x2, y: yN))
                    paths.append(p)
                    i += 1; ni += 1
                }
            }
        }
        return paths
    }

    var body: some View {
        if rounds.isEmpty {
            ContentUnavailableView(
                "Bracket Not Available",
                systemImage: "soccerball",
                description: Text("The knockout bracket will appear once the group stage is complete.")
            )
        } else {
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Connector lines
                    let paths = connectorPaths
                    ForEach(paths.indices, id: \.self) { i in
                        paths[i]
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    }

                    // Round headers + match cards
                    ForEach(Array(rounds.enumerated()), id: \.offset) { ri, round in
                        // Round header
                        Text(shortRoundName(round.name))
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: cardW, alignment: .center)
                            .position(x: xForRound(ri) + cardW / 2, y: 14)

                        ForEach(Array(round.matches.enumerated()), id: \.element.id) { mi, match in
                            BracketCard(match: match)
                                .frame(width: cardW, height: cardH)
                                .position(
                                    x: xForRound(ri) + cardW / 2,
                                    y: yForMatch(round: ri, match: mi) + cardH / 2
                                )
                        }
                    }
                }
                .frame(width: canvasW, height: canvasH)
            }
        }
    }
}

// MARK: - Bracket Card

struct BracketCard: View {
    let match: Match

    private var team1Won: Bool {
        guard let s1 = match.score1, let s2 = match.score2 else { return false }
        if s1 != s2 { return s1 > s2 }
        if let p = match.score?.p, p.count == 2 { return p[0] > p[1] }
        return false
    }

    private var team2Won: Bool {
        guard let s1 = match.score1, let s2 = match.score2 else { return false }
        if s1 != s2 { return s2 > s1 }
        if let p = match.score?.p, p.count == 2 { return p[1] > p[0] }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            teamRow(name: match.team1, score: match.score1, isWinner: team1Won)
            Divider()
            teamRow(name: match.team2, score: match.score2, isWinner: team2Won)
            Divider()
            Text(shortDate(match.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 3)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
    }

    @ViewBuilder
    private func teamRow(name: String, score: Int?, isWinner: Bool) -> some View {
        let hasResult = match.score1 != nil
        HStack(spacing: 6) {
            Text(name.isEmpty ? "TBD" : "\(countryFlag(name)) \(name)")
                .font(.caption.bold())
                .foregroundStyle(
                    isWinner ? .primary :
                    hasResult ? Color.primary.opacity(0.5) : .primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let s = score {
                Text("\(s)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(isWinner ? .primary : Color.primary.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 25)
        .background(isWinner ? Color.green.opacity(0.12) : Color.clear)
    }

    private func shortDate(_ raw: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: raw) else { return raw }
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }
}

#Preview {
    ContentView()
}
