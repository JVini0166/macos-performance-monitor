import Foundation

/// Stable preference codes; display names are intentionally written in each language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt-BR"
    case english = "en-US"
    var id: Self { self }
    var title: String { self == .portuguese ? "Português (Brasil)" : "English (US)" }
    var resource: String { self == .portuguese ? "pt-BR" : "en" }
    static var initial: Self { Locale.preferredLanguages.first?.hasPrefix("pt") == true ? .portuguese : .english }
}

enum L10n {
    static let preferenceKey = "appLanguage"
    static var language: AppLanguage { UserDefaults.standard.string(forKey: preferenceKey).flatMap(AppLanguage.init(rawValue:)) ?? .initial }
    static var locale: Locale { Locale(identifier: language.rawValue) }
    private static let bundles: [AppLanguage: Bundle] = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.compactMap { language in
        Bundle.module.path(forResource: language.resource, ofType: "lproj").flatMap(Bundle.init(path:)).map { (language, $0) }
    })
    static func text(_ key: String, language: AppLanguage = language) -> String {
        bundles[language]?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
    }
    private static let byteFormatters: [AppLanguage: NumberFormatter] = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.map { language in
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return (language, formatter)
    })
    static func number(_ format: String, _ arguments: CVarArg...) -> String {
        String(format: text(format), locale: locale, arguments: arguments)
    }
    static func bytes(_ value: Double, language: AppLanguage = language) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var amount = max(0, value.isFinite ? value : 0)
        var unit = 0
        while amount >= 1024 && unit < units.count - 1 { amount /= 1024; unit += 1 }
        let displayed = unit == 0 ? amount.rounded() : amount
        return "\(byteFormatters[language]?.string(from: NSNumber(value: displayed)) ?? "0") \(units[unit])"
    }
}

/// Keeps interpolation arguments separate from translation keys (and never formats user data).
struct LocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    let key: String
    let arguments: [String]
    init(stringLiteral value: String) { key = value; arguments = [] }
    init(stringInterpolation: StringInterpolation) { key = stringInterpolation.key; arguments = stringInterpolation.arguments }
    struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        init(literalCapacity: Int, interpolationCount: Int) { arguments.reserveCapacity(interpolationCount) }
        mutating func appendLiteral(_ literal: String) { key += literal }
        mutating func appendInterpolation<T>(_ value: T) { key += "%@"; arguments.append(String(describing: value)) }
    }
    func resolved(language: AppLanguage = L10n.language) -> String {
        let translated = L10n.text(key, language: language)
        guard !arguments.isEmpty else { return translated }
        let parts = translated.components(separatedBy: "%@")
        guard parts.count == arguments.count + 1 else { return key }
        return zip(parts.dropLast(), arguments).map { $0 + $1 }.joined() + (parts.last ?? "")
    }
}
func L(_ message: LocalizedMessage) -> String { message.resolved() }
