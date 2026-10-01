import SwiftUI

@main struct MiniDeskApp: App {
    @State private var store = DeskStore()
    var body: some Scene {
        WindowGroup { RootView().environment(store).tint(Color.accentColor) }
    }
}
