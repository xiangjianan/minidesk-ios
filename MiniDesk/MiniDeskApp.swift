import SwiftUI

@main struct MiniDeskApp: App {
    @State private var store = DeskStore()
    @AppStorage(AppLanguage.key) private var language = "system"
    var body: some Scene {
        WindowGroup { RootView().environment(store).environment(\.locale, Locale(identifier: AppLanguage.identifier)).tint(Color.accentColor) }
    }
}
