import Foundation
import AppKit
import SwiftUI


extension AppDelegate {
    // MARK: - Menu Bar Setup

    /// Sets up the status bar menu with various options.
    func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: "Server Status")
        }

        let menu = NSMenu()

        // Status Menu (non-clickable)
        statusMenuItem = NSMenuItem(title: "Status: Unknown", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false // Disabled to prevent clicking
        menu.addItem(statusMenuItem!)

        // Add a line for IP address and port
        ipAddressMenuItem = NSMenuItem(title: "IP: Unknown", action: nil, keyEquivalent: "")
        ipAddressMenuItem?.isEnabled = false
        menu.addItem(ipAddressMenuItem!)

        // Add action for Start/Stop
        startStopMenuItem = NSMenuItem(title: "Start Server", action: #selector(toggleServerFromMenu), keyEquivalent: "S")
        menu.addItem(startStopMenuItem!)

        // Add action for Pause/Run
        pauseRunMenuItem = NSMenuItem(title: "Pause", action: #selector(togglePauseFromMenu), keyEquivalent: "P")
        menu.addItem(pauseRunMenuItem!)

        // Add action to open settings
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(showSettings), keyEquivalent: "O"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "Q"))
        statusItem?.menu = menu

        // Update initial status
        updateStatusMenuItem()
        updatePauseRunMenuItem()
        updateStartStopMenuItem()
        updateIpAddressMenuItem()
    }
    
    // MARK: - Menu Actions

    /// Toggles the pause state from the menu.
    @objc private func togglePauseFromMenu() {
        togglePause()
    }
    
    /// Toggles the server state from the menu.
    @objc func toggleServerFromMenu() {
        if isServerRunning {
            stopServer()
        } else {
            guard let portInt = Int(UserDefaults.standard.string(forKey: "Port") ?? "8080"),
                  (1...65535).contains(portInt) else {
                print("❌ Invalid port")
                return
            }
            startServer(on: portInt)
        }
    }

    
    /// Opens the settings window.
    @objc func showSettings() {
        if settingsWindowController == nil {
            let settingsView = SettingsView(closeWindow: {
                self.settingsWindowController?.close()
                self.settingsWindowController = nil
            })

            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )

            settingsWindow.title = "Settings"
            settingsWindow.center()
            settingsWindow.contentViewController = NSHostingController(rootView: settingsView.environmentObject(self))
            settingsWindowController = NSWindowController(window: settingsWindow)
        }

        // Ensure the window appears in the foreground
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Quits the application.
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
