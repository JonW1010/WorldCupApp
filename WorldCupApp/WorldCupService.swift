import Foundation

final class WorldCupService: ObservableObject {

    private let url = URL(string:
        "https://raw.githubusercontent.com/openfootball/worldcup.json/master/2026/worldcup.json"
    )!

    @Published var matches: [Match] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Total goals scored by each player across the whole tournament.
    var tournamentGoals: [String: Int] {
        var tally: [String: Int] = [:]
        for match in matches {
            for goal in (match.goals1 ?? []) + (match.goals2 ?? []) {
                tally[goal.name, default: 0] += 1
            }
        }
        return tally
    }

    /// Top 25 goalscorers sorted by goals descending; country derived from match data.
    var topGoalscorers: [GoalscorerInfo] {
        var tally: [String: (goals: Int, country: String)] = [:]
        for match in matches {
            for goal in (match.goals1 ?? []) {
                let current = tally[goal.name]
                tally[goal.name] = ((current?.goals ?? 0) + 1, match.team1)
            }
            for goal in (match.goals2 ?? []) {
                let current = tally[goal.name]
                tally[goal.name] = ((current?.goals ?? 0) + 1, match.team2)
            }
        }
        return tally
            .map { GoalscorerInfo(name: $0.key, goals: $0.value.goals, country: $0.value.country) }
            .sorted {
                if $0.goals != $1.goals { return $0.goals > $1.goals }
                return $0.name < $1.name
            }
            .prefix(25)
            .map { $0 }
    }

    /// Teams that have not yet been eliminated from a knockout-stage match.
    var activeTeams: Set<String> {
        var all = Set<String>()
        var eliminated = Set<String>()

        for match in matches {
            all.insert(match.team1)
            all.insert(match.team2)

            guard match.isKnockoutRound,
                  let s1 = match.score1, let s2 = match.score2 else { continue }

            if s1 < s2 {
                eliminated.insert(match.team1)
            } else if s2 < s1 {
                eliminated.insert(match.team2)
            } else if let p = match.score?.p, p.count == 2 {
                // Penalty shootout decides the loser
                eliminated.insert(p[0] < p[1] ? match.team1 : match.team2)
            }
        }

        return all.subtracting(eliminated)
    }

    @MainActor
    func fetchResults() async {
        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoded = try JSONDecoder().decode(WorldCupResponse.self, from: data)

            matches = decoded.matches
                .filter(\.hasResult)
                .sorted { $0.sortKey < $1.sortKey }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
