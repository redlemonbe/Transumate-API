import Cocoa
import SwiftUI
import Vapor
import Network
import Combine
import Foundation

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
    
    // MARK: - Application Lifecycle

    /// Called when the application has finished launching.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        checkDirectories()
        setupStatusBarMenu()
        toggleServer() // Automatically starts the server with the configured port
    }

    
    /// Called when the application is about to terminate.
    func applicationWillTerminate(_ notification: Notification) {
        stopServer() // Properly stops the server before quitting the application
    }
    
    // MARK: - Python Script Execution

    /// Executes a Python script within the application's environment.
    /// - Parameter scriptName: The name of the Python script to execute.
    func executePythonScript(_ scriptName: String) {
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let envDirectory = homePath.appendingPathComponent(".transumate") // Environment directory
        let scriptPath = homePath.appendingPathComponent(".transumate/\(scriptName)") // Script path

        // Command to execute the Python script within the environment
        let command = "\(envDirectory.path)/bin/python \(scriptPath.path)"

        do {
            try executeShellCommand(command)
            print("✅ Python script \(scriptName) executed successfully.")
        } catch {
            print("❌ Failed to execute Python script \(scriptName): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling

    /// Displays an error alert with a given message.
    /// - Parameter message: The error message to display.
    func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Python Environment Management

    /// Creates a Python virtual environment for the application.
    func createPythonEnvironment() {
        print("🔧 Setting up Python environment...")
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let envDirectory = homePath.appendingPathComponent(".transumate") // Root of the environment

        // Check if the environment already exists
        if FileManager.default.fileExists(atPath: envDirectory.path) {
            print("✅ Python environment already exists at: \(envDirectory.path)")
            return
        }

        // Command to create the Python environment
        let createEnvCommand = "python3 -m venv \(envDirectory.path)"

        do {
            try executeShellCommand(createEnvCommand)
            print("✅ Python environment created at: \(envDirectory.path)")
            directoryStatusMessage = "Python environment created successfully."
            directoryStatusColor = .green
        } catch {
            print("❌ Failed to create Python environment: \(error.localizedDescription)")
            directoryStatusMessage = "Failed to create Python environment: \(error.localizedDescription)"
            directoryStatusColor = .red
        }
    }
    
    /// Executes a shell command.
    /// - Parameter command: The command to execute.
    /// - Throws: An error if the command fails.
    private func executeShellCommand(_ command: String) throws {
        let process = Process()
        process.launchPath = "/bin/zsh" // Use zsh or bash depending on your configuration
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.launch()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorMessage = String(data: errorData, encoding: .utf8) {
                throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        }
    }
    
    // MARK: - Menu Bar Setup

    /// Sets up the status bar menu with various options.
    private func setupStatusBarMenu() {
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
    
    /// Toggles the pause state of the server.
    func togglePause() {
        guard isServerRunning else { return } // Do nothing if the server is stopped
        isPaused.toggle()
        updatePauseRunMenuItem() // Update the "Pause/Run" menu item
        updateStatusMenuItem() // Update the status menu item
        print("🔄 Server is now \(isPaused ? "Paused" : "Running")")
    }

    /// Toggles the server state (start/stop).
    func toggleServer() {
        // Check if required files and directories are present
        checkDirectories()
        if directoryStatusColor == .red {
            print("❌ Required directories or files are missing. Server will not start.")
            directoryStatusMessage = "Cannot start server: directories or files are missing."
            return
        }

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

    /// Starts the server on the specified port.
    /// - Parameter port: The port number to start the server on.
    func startServer(on port: Int) {
        // Ensure required files and directories are present
        checkDirectories()

        if directoryStatusColor == .red {
            print("❌ Missing configuration. Server will not start.")
            if let window = NSApp.keyWindow, !window.isKind(of: NSAlert.self) {
                showErrorAlert(message: """
                Missing configuration files or directories.
                Go to Settings and click Install to set up the environment.
                """)
            }
            return
        }

        DispatchQueue.global(qos: .background).async {
            do {
                let app = try self.configureServer(on: port)
                try app.start()
                DispatchQueue.main.async {
                    self.server = app
                    self.isServerRunning = true
                    self.updatePauseRunMenuItem() // Update the "Pause/Run" menu item
                    self.updateStartStopMenuItem() // Update the "Start/Stop" menu item
                    self.updateStatusMenuItem() // Update the status menu item
                    self.updateIpAddressMenuItem(port: port) // Update the IP address
                    print("✅ Server started on port \(port)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatusMenuItem() // Update the status menu item
                    print("❌ Failed to start server: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Stops the server.
    func stopServer() {
        DispatchQueue.global(qos: .background).async {
            self.server?.shutdown()
            DispatchQueue.main.async {
                self.server = nil
                self.isServerRunning = false
                self.isPaused = false // Reset pause state
                self.updatePauseRunMenuItem() // Update the "Pause/Run" menu item
                self.updateStartStopMenuItem() // Update the "Start/Stop" menu item
                self.updateStatusMenuItem() // Update the status menu item
                self.updateIpAddressMenuItem() // Update the IP address
                print("ℹ️ Server stopped")
            }
        }
    }

    /// Configures the server with the specified port.
    /// - Parameter port: The port number to configure the server on.
    /// - Throws: An error if the server configuration fails.
    func configureServer(on port: Int) throws -> Application {
        let app = try createServer(on: port, appDelegate: self)
        return app
    }
    
    /// Updates the status menu item based on the server state.
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

    /// Updates the "Pause/Run" menu item.
    func updatePauseRunMenuItem() {
        if isServerRunning {
            pauseRunMenuItem?.title = isPaused ? "Run" : "Pause"
            pauseRunMenuItem?.isHidden = false
        } else {
            pauseRunMenuItem?.isHidden = true
        }
    }

    /// Updates the "Start/Stop" menu item.
    func updateStartStopMenuItem() {
        startStopMenuItem?.title = isServerRunning ? "Stop Server" : "Start Server"
    }

    /// Updates the IP address menu item.
    /// - Parameter port: Optional port number to include in the display.
    func updateIpAddressMenuItem(port: Int? = nil) {
        guard let ipAddress = getPrimaryIPAddress(),
              let validPort = port, (1...65535).contains(validPort) else {
            ipAddressMenuItem?.title = "IP: none"
            return
        }
        ipAddressMenuItem?.title = "IP: \(ipAddress):\(validPort)"
    }
    
    /// Gets the primary IP address of the machine.
    /// - Returns: The primary IP address or `nil` if unavailable.
    func getPrimaryIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }

                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) { // IPv4 only
                    if let name = interface.ifa_name,
                       String(cString: name) == "en0" { // Primary interface on macOS
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
  
    /// Installs the Python environment, required directories, and files.
    func installFiles() {
        print("🔧 Installing Python environment, directories, and files...")
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let mainDirectory = homePath.appendingPathComponent(".transumate")
        let modelsDirectory = mainDirectory.appendingPathComponent("models")

        // Create Python environment first
        createPythonEnvironment()

        do {
            // Create directories
            if !FileManager.default.fileExists(atPath: mainDirectory.path) {
                try FileManager.default.createDirectory(at: mainDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ Main directory created at: \(mainDirectory.path)")
            }
            if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
                try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ 'models' directory created at: \(modelsDirectory.path)")
            }

            // Copy Python files to the main directory
            try copyFile(from: "Translate", withExtension: "py", to: mainDirectory)
            try copyFile(from: "Install_swift", withExtension: "py", to: mainDirectory)

            directoryStatusMessage = "Python environment, directories, and files successfully installed."
            directoryStatusColor = .green
        } catch {
            print("❌ Error during installation: \(error.localizedDescription)")
            directoryStatusMessage = "Error during installation: \(error.localizedDescription)"
            directoryStatusColor = .red
        }
    }

    /// Deletes the application's directories and environment.
    func deleteDirectories() {
        print("🗑 Deleting directories...")
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let mainDirectory = homePath.appendingPathComponent(".transumate")

        do {
            // Check if the main directory exists
            if FileManager.default.fileExists(atPath: mainDirectory.path) {
                // Stop the server before deleting directories
                if isServerRunning {
                    print("🔄 Stopping the server before deleting directories...")
                    stopServer()
                }

                // Recursively delete files and directories
                try FileManager.default.removeItem(at: mainDirectory)

                directoryStatusMessage = "Directories and Python environment successfully deleted."
                directoryStatusColor = .green
                print("✅ Directories and Python environment deleted successfully.")
            } else {
                directoryStatusMessage = "Directories do not exist."
                directoryStatusColor = .red
                print("ℹ️ No directories to delete.")
            }
        } catch {
            print("❌ Failed to delete directories: \(error.localizedDescription)")
            directoryStatusMessage = "Failed to delete directories: \(error.localizedDescription)"
            directoryStatusColor = .red
        }
    }

    /// Verifies the existence of directories and required files.
    func checkDirectories() {
        print("🔍 Checking directories and files...")
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let mainDirectory = homePath.appendingPathComponent(".transumate")
        let mainFile = mainDirectory.appendingPathComponent("Translate.py")
        let modelsFile = mainDirectory.appendingPathComponent("Install_swift.py")

        if FileManager.default.fileExists(atPath: mainDirectory.path) &&
            FileManager.default.fileExists(atPath: mainFile.path) &&
            FileManager.default.fileExists(atPath: modelsFile.path) {
            directoryStatusMessage = "Directories and files are correctly configured."
            directoryStatusColor = .green
            print("✅ All directories and files exist.")
        } else {
            directoryStatusMessage = "Directories or files are missing."
            directoryStatusColor = .red
            print("⚠️ Directories or files are missing.")
        }
    }

    /// Copies a resource file from the app bundle to a specified directory.
    private func copyFile(from resourceName: String, withExtension fileExtension: String, to destinationDirectory: URL) throws {
        guard let resourceURL = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            throw NSError(domain: "FileCopyError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Resource \(resourceName).\(fileExtension) not found in the bundle"])
        }

        let destinationURL = destinationDirectory.appendingPathComponent(resourceURL.lastPathComponent)

        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            print("📄 Copying \(resourceName).\(fileExtension) to \(destinationDirectory.path)...")
            try FileManager.default.copyItem(at: resourceURL, to: destinationURL)
            print("✅ File \(resourceName).\(fileExtension) copied to \(destinationDirectory.path)")
        } else {
            print("📄 File \(resourceName).\(fileExtension) already exists in \(destinationDirectory.path)")
        }
    }
}
