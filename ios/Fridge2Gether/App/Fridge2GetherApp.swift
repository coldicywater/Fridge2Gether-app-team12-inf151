import SwiftUI
import FirebaseCore

@main
struct Fridge2GetherApp: App {
    @State private var store = AppStore()
    private let firebaseConfigured: Bool

    init() {
        // Firebase needs GoogleService-Info.plist. Without it we show setup steps instead of crashing.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            firebaseConfigured = true
        } else {
            firebaseConfigured = false
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .task { await store.start(firebaseConfigured: firebaseConfigured) }
        }
    }
}
