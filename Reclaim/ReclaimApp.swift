import SwiftUI
import UserNotifications

@main
struct ReclaimApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .frame(minWidth: 950, minHeight: 650)
                .preferredColorScheme(.dark) // Give Reclaim a premium, sleek dark look by default
                .task {
                    try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
}
