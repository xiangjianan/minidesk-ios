import Foundation

nonisolated public enum AppLanguage {
    public static let key = "appLanguage"

    public static var identifier: String {
        let choice = UserDefaults.standard.string(forKey: key) ?? "system"
        if choice == "zh-Hans" || choice == "en" { return choice }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh-Hans" : "en"
    }
}

nonisolated public func L(_ key: String) -> String {
    guard AppLanguage.identifier == "en",
          let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
          let bundle = Bundle(path: path) else { return key }
    return bundle.localizedString(forKey: key, value: key, table: nil)
}
