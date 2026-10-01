import SwiftUI

@main
struct AgyLimitsBarApp: App {
    @StateObject private var statusModel = AgyStatusModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(statusModel)
        } label: {
            MenuBarLabel(model: statusModel)
        }
        .menuBarExtraStyle(.window)
    }
}
