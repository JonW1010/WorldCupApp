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

// MARK: - Country Flag Emoji

/// Returns the flag emoji for a country name.
func countryFlag(_ name: String) -> String {
    // Home nations use subdivision flags not covered by ISO 3166-1 alpha-2
    switch name {
    case "England": return "🏴󠁧󠁢󠁥󠁮󠁧󠁿"
    case "Scotland": return "🏴󠁧󠁢󠁳󠁣󠁴󠁿"
    case "Wales":    return "🏴󠁧󠁢󠁷󠁬󠁳󠁿"
    default: break
    }
    guard let code = isoCode[name] else { return "" }
    // Pair of regional indicator symbols derived from the 2-letter ISO code
    return code.unicodeScalars.compactMap {
        UnicodeScalar(0x1F1E6 + $0.value - 65)
    }.reduce("") { $0 + String($1) }
}

private let isoCode: [String: String] = [
    "Afghanistan": "AF", "Albania": "AL", "Algeria": "DZ", "Angola": "AO",
    "Argentina": "AR", "Armenia": "AM", "Australia": "AU", "Austria": "AT",
    "Azerbaijan": "AZ", "Bahrain": "BH", "Belgium": "BE", "Benin": "BJ",
    "Bolivia": "BO", "Bosnia": "BA", "Bosnia and Herzegovina": "BA",
    "Brazil": "BR", "Bulgaria": "BG", "Burkina Faso": "BF",
    "Cambodia": "KH", "Cameroon": "CM", "Canada": "CA", "Cape Verde": "CV",
    "Chile": "CL", "China": "CN", "China PR": "CN",
    "Colombia": "CO", "Comoros": "KM", "Congo": "CG", "Costa Rica": "CR",
    "Croatia": "HR", "Cuba": "CU", "Czech Republic": "CZ", "Czechia": "CZ",
    "DR Congo": "CD", "Denmark": "DK",
    "Ecuador": "EC", "Egypt": "EG", "El Salvador": "SV",
    "Equatorial Guinea": "GQ", "Ethiopia": "ET",
    "Finland": "FI", "France": "FR", "Gabon": "GA",
    "Germany": "DE", "Ghana": "GH", "Greece": "GR",
    "Guatemala": "GT", "Guinea": "GN", "Guinea-Bissau": "GW",
    "Haiti": "HT", "Honduras": "HN", "Hungary": "HU",
    "Iceland": "IS", "Indonesia": "ID", "Iran": "IR", "Iraq": "IQ",
    "Ireland": "IE", "Israel": "IL", "Italy": "IT", "Ivory Coast": "CI",
    "Jamaica": "JM", "Japan": "JP", "Jordan": "JO",
    "Kazakhstan": "KZ", "Kenya": "KE", "Kuwait": "KW", "Kyrgyzstan": "KG",
    "Lebanon": "LB", "Liberia": "LR", "Libya": "LY",
    "Malaysia": "MY", "Mali": "ML", "Mauritania": "MR", "Mexico": "MX",
    "Moldova": "MD", "Montenegro": "ME", "Morocco": "MA", "Mozambique": "MZ",
    "Namibia": "NA", "Netherlands": "NL", "New Zealand": "NZ",
    "Nigeria": "NG", "North Korea": "KP", "North Macedonia": "MK", "Norway": "NO",
    "Oman": "OM",
    "Palestine": "PS", "Panama": "PA", "Paraguay": "PY", "Peru": "PE",
    "Philippines": "PH", "Poland": "PL", "Portugal": "PT",
    "Qatar": "QA", "Romania": "RO", "Russia": "RU", "Rwanda": "RW",
    "Saudi Arabia": "SA", "Senegal": "SN", "Serbia": "RS",
    "Sierra Leone": "SL", "Slovakia": "SK", "Slovenia": "SI",
    "South Africa": "ZA", "South Korea": "KR", "Spain": "ES",
    "Sudan": "SD", "Sweden": "SE", "Switzerland": "CH", "Syria": "SY",
    "Tanzania": "TZ", "Thailand": "TH", "Trinidad and Tobago": "TT",
    "Tunisia": "TN", "Turkey": "TR", "Türkiye": "TR",
    "UAE": "AE", "Uganda": "UG", "Ukraine": "UA",
    "United Arab Emirates": "AE", "United States": "US", "USA": "US",
    "Uruguay": "UY", "Uzbekistan": "UZ",
    "Venezuela": "VE", "Vietnam": "VN",
    "Zambia": "ZM", "Zimbabwe": "ZW",
]
