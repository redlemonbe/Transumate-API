import Cocoa
import SwiftUI
import Vapor
import Network
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var settingsWindowController: NSWindowController?
    var statusMenuItem: NSMenuItem? // Stocke l'élément de menu du statut
    var pauseRunMenuItem: NSMenuItem? // Stocke l'élément "Pause/Run"
    var startStopMenuItem: NSMenuItem? // Stocke l'élément "Start/Stop"
    var ipAddressMenuItem: NSMenuItem? // Stocke l'élément pour l'adresse IP et le port
    var server: Application?
    @Published var isServerRunning: Bool = false
    @Published var isPaused: Bool = false // Ajout de la variable observable pour l'état de pause
    @Published var directoryStatusMessage: String = ""
    @Published var directoryStatusColor: Color = .red
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBarMenu()
        toggleServer() // Démarre automatiquement le serveur avec le port configuré
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        stopServer() // Arrête le serveur proprement avant de quitter l'application
    }
    
    // MARK: - Barre de menus
    private func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: "Server Status")
        }
        
        let menu = NSMenu()
        
        // Menu Status (non cliquable)
        statusMenuItem = NSMenuItem(title: "Status: Unknown", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false // Désactivé pour empêcher le clic
        menu.addItem(statusMenuItem!)
        
        // Ajouter une ligne pour l'adresse IP et le port
        ipAddressMenuItem = NSMenuItem(title: "IP: Unknown", action: nil, keyEquivalent: "")
        ipAddressMenuItem?.isEnabled = false
        menu.addItem(ipAddressMenuItem!)
        
        // Ajouter une action pour Start/Stop
        startStopMenuItem = NSMenuItem(title: "Start Server", action: #selector(toggleServerFromMenu), keyEquivalent: "S")
        menu.addItem(startStopMenuItem!)
        
        // Ajouter une action pour Pause/Run
        pauseRunMenuItem = NSMenuItem(title: "Pause", action: #selector(togglePauseFromMenu), keyEquivalent: "P")
        menu.addItem(pauseRunMenuItem!)
        
        // Ajouter une action pour ouvrir les paramètres
        menu.addItem(NSMenuItem(title: "Open Settings", action: #selector(showSettings), keyEquivalent: "O"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "Q"))
        statusItem?.menu = menu
        
        // Mettre à jour le statut initial
        updateStatusMenuItem()
        updatePauseRunMenuItem()
        updateStartStopMenuItem()
        updateIpAddressMenuItem()
    }
    
    @objc private func togglePauseFromMenu() {
        togglePause()
    }
    
    @objc private func toggleServerFromMenu() {
        toggleServer()
    }
    
    // MARK: - Fenêtre des paramètres
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
        
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Gestion du serveur
    func togglePause() {
        guard isServerRunning else { return } // Ne rien faire si le serveur est arrêté
        isPaused.toggle()
        updatePauseRunMenuItem() // Met à jour le titre du menu Pause/Run
        updateStatusMenuItem() // Met à jour le menu avec le nouveau statut
        print("🔄 Server is now \(isPaused ? "Paused" : "Running")")
    }
    
    func toggleServer() {
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
    
    func startServer(on port: Int) {
        DispatchQueue.global(qos: .background).async {
            do {
                let app = try self.configureServer(on: port)
                try app.start()
                DispatchQueue.main.async {
                    self.server = app
                    self.isServerRunning = true
                    self.updatePauseRunMenuItem() // Met à jour le titre du menu Pause/Run
                    self.updateStartStopMenuItem() // Mettre à jour le menu Start/Stop
                    self.updateStatusMenuItem() // Mettre à jour le menu
                    self.updateIpAddressMenuItem(port: port) // Mettre à jour l'adresse IP
                    print("✅ Server started on port \(port)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatusMenuItem() // Mettre à jour le menu
                    print("❌ Failed to start server: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func stopServer() {
        DispatchQueue.global(qos: .background).async {
            self.server?.shutdown()
            DispatchQueue.main.async {
                self.server = nil
                self.isServerRunning = false
                self.isPaused = false // Réinitialiser l'état de pause
                self.updatePauseRunMenuItem() // Met à jour le titre du menu Pause/Run
                self.updateStartStopMenuItem() // Mettre à jour le menu Start/Stop
                self.updateStatusMenuItem() // Mettre à jour le menu
                self.updateIpAddressMenuItem() // Mettre à jour l'adresse IP
                print("ℹ️ Server stopped")
            }
        }
    }
    
    // MARK: - Configuration du serveur
    func configureServer(on port: Int) throws -> Application {
        // Appel à la fonction renommée de Server.swift
        let app = try createServer(on: port, appDelegate: self) // Utilisation explicite
        return app
    }
    
    func updateStatusMenuItem() {
        var statusText = "Unknown"
        if isServerRunning {
            statusText = isPaused ? "Paused" : "Running"
        } else {
            statusText = "Stopped"
        }
        
        print("🔄 Updating status menu item: \(statusText)")
        statusMenuItem?.title = "Status: \(statusText)"
    }
    
    func updatePauseRunMenuItem() {
        if isServerRunning {
            pauseRunMenuItem?.title = isPaused ? "Run" : "Pause"
            pauseRunMenuItem?.isHidden = false
        } else {
            pauseRunMenuItem?.isHidden = true
        }
    }
    
    func updateStartStopMenuItem() {
        startStopMenuItem?.title = isServerRunning ? "Stop Server" : "Start Server"
    }
    
    func updateIpAddressMenuItem(port: Int? = nil) {
        guard let ipAddress = getPrimaryIPAddress(),
              let validPort = port, (1...65535).contains(validPort) else {
            ipAddressMenuItem?.title = "IP: none"
            return
        }
        ipAddressMenuItem?.title = "IP: \(ipAddress):\(validPort)"
    }
    
    // MARK: - Utilitaire pour obtenir l'adresse IP principale
    func getPrimaryIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) { // IPv4 uniquement
                    if let name = interface.ifa_name,
                       String(cString: name) == "en0" { // Interface principale sur macOS
                        var addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(INET_ADDRSTRLEN))
                        inet_ntop(Int32(addrFamily), &addr.sin_addr, buffer, socklen_t(INET_ADDRSTRLEN))
                        address = String(cString: buffer)
                        buffer.deallocate()
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
  
    // MARK: - Delete and create directory
    /// Creates the necessary directories for the application.
    /// Ensures the main directory and `models` subdirectory exist.
    func createDirectories() {
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            let mainDirectory = homePath.appendingPathComponent(".TrasumateAPI")
            let modelsDirectory = mainDirectory.appendingPathComponent("models")
            
            do {
                try FileManager.default.createDirectory(at: mainDirectory, withIntermediateDirectories: true, attributes: nil)
                try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
                directoryStatusMessage = "Directories successfully created."
                directoryStatusColor = .green
            } catch {
                directoryStatusMessage = "Failed to create directories: \(error.localizedDescription)"
                directoryStatusColor = .red
            }
        }

        func deleteDirectories() {
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            let mainDirectory = homePath.appendingPathComponent(".TrasumateAPI")
            
            do {
                if FileManager.default.fileExists(atPath: mainDirectory.path) {
                    try FileManager.default.removeItem(at: mainDirectory)
                    directoryStatusMessage = "Directories successfully deleted."
                    directoryStatusColor = .green
                } else {
                    directoryStatusMessage = "Directories do not exist."
                    directoryStatusColor = .red
                }
            } catch {
                directoryStatusMessage = "Failed to delete directories: \(error.localizedDescription)"
                directoryStatusColor = .red
            }
        }

        func checkDirectories() {
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            let mainDirectory = homePath.appendingPathComponent(".TrasumateAPI")
            let modelsDirectory = mainDirectory.appendingPathComponent("models")
            
            if FileManager.default.fileExists(atPath: mainDirectory.path) && FileManager.default.fileExists(atPath: modelsDirectory.path) {
                directoryStatusMessage = "Directories exist and are correctly configured."
                directoryStatusColor = .green
            } else {
                directoryStatusMessage = "Directories are missing."
                directoryStatusColor = .red
            }
        }
}
