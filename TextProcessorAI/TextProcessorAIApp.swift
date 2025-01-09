import SwiftUI

@main
struct TextProcessorAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() } // Évite de générer une fenêtre par défaut
    }
}
