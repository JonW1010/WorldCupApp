import Foundation

// MARK: - Top-level response

struct WorldCupResponse: Decodable {
    let name: String
    let matches: [Match]
}

// MARK: - Score

struct Score: Decodable {
    let ft: [Int]?   // full time: [goals1, goals2]
    let et: [Int]?   // extra time
    let p: [Int]?    // penalties
}

// MARK: - Goal

struct Goal: Decodable {
    let name: String
    let minute: String?
    let penalty: Bool?

    var isPenalty: Bool { penalty == true }
}

// MARK: - Match

struct Match: Decodable, Identifiable {
    let round: String?
    let date: String
    let time: String?
    let team1: String
    let team2: String
    let score: Score?
    let goals1: [Goal]?
    let goals2: [Goal]?
    let group: String?
    let ground: String?

    // Stable ID from content
    var id: String { "\(date)-\(team1)-\(team2)" }

    var hasResult: Bool { score?.ft != nil }

    var score1: Int? { score?.ft?[safe: 0] }
    var score2: Int? { score?.ft?[safe: 1] }

    var scoreDisplay: String {
        guard let s1 = score1, let s2 = score2 else { return "–" }
        var text = "\(s1) – \(s2)"
        if let e = score?.et, e.count == 2 { text += " (AET)" }
        if let p = score?.p,  p.count == 2 { text += " (PSO \(p[0])–\(p[1]))" }
        return text
    }

    /// Key used for alphabetical sorting
    var sortKey: String { "\(team1) vs \(team2)" }

    /// True for knockout-stage rounds (Round of 32/16, QF, SF, Final, etc.)
    var isKnockoutRound: Bool {
        guard let r = round?.lowercased() else { return false }
        return r.contains("round of") || r.contains("final") || r.contains("play")
    }
}

// MARK: - Safe array subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Goalscorer Info

struct GoalscorerInfo: Identifiable {
    let name: String
    let goals: Int
    let country: String
    var id: String { name }
}

// MARK: - Wikipedia Summary

struct WikiSummary: Decodable {
    struct Thumbnail: Decodable {
        let source: String
    }
    let description: String?
    let extract: String?
    let thumbnail: Thumbnail?
}
