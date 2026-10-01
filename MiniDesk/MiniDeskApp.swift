import SwiftUI

@main struct MiniDeskApp: App {
    @State private var store = DeskStore()
    var body: some Scene {
        WindowGroup { RootView().environment(store).tint(Color(red: 0.13, green: 0.43, blue: 0.36)) }
    }
}
