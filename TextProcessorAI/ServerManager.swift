import Foundation
import AppKit
import Vapor
import Network

/// Server management extension for AppDelegate
extension AppDelegate {
    
    /// Manages the server and its interactions
    class ServerManager {
        private let appDelegate: AppDelegate

        init(appDelegate: AppDelegate) {
            self.appDelegate = appDelegate
        }

        /// Stops the Python script explicitly
        func stopPythonScript() {
            appDelegate.terminatePythonScript()
            print("ℹ️ Python script stopped via ServerManager.")
        }
    }

    /// Toggles the pause state of the server
    func togglePause() {
        guard isServerRunning else { return } // No action if the server is stopped
        
        isPaused.toggle() // Toggle the pause state
        
        // Kill the Python script if the server is paused
        if isPaused {
            terminatePythonScript()
            print("⏸️ Server paused, Python script terminated.")
        } else {
            print("▶️ Server resumed.")
        }

        // Update UI elements
        updatePauseRunMenuItem()
        updateStatusMenuItem()
    }
    
    /// Toggles the server state between start and stop
    func toggleServer() {
        checkDirectories() // Ensure all required directories exist

        // Stop the server if running
        if isServerRunning {
            stopServer()
            return
        }
        
        // Start the server if stopped
        guard let port = Int(UserDefaults.standard.string(forKey: "Port") ?? "5001"),
              (1...65535).contains(port) else {
            print("❌ Invalid port")
            return
        }
        startServer(on: port)
    }
    
    /// Starts the server on the specified port
    func startServer(on port: Int) {
        checkDirectories()
        
        // Abort if configuration is incomplete
        if directoryStatusColor == .red {
            showConfigurationError()
            return
        }
        
        // Run the server in the background
        DispatchQueue.global(qos: .background).async {
            do {
                let app = try self.configureServer(on: port)
                try app.start()
                DispatchQueue.main.async {
                    self.server = app
                    self.isServerRunning = true
                    self.updateUIAfterServerStart(port: port)
                    print("✅ Server started on port \(port)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.updateStatusMenuItem()
                    print("❌ Failed to start server: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Stops the server and resets states
    func stopServer() {
        DispatchQueue.global(qos: .background).async {
            self.server?.shutdown()
            DispatchQueue.main.async {
                self.terminatePythonScript() // Ensure Python script is terminated
                self.resetServerState()
                print("ℹ️ Server stopped")
            }
        }
    }
    
    /// Configures the server on the specified port
    func configureServer(on port: Int) throws -> Application {
        return try createServer(on: port, appDelegate: self)
    }
    
    /// Updates the status menu item based on server state
    func updateStatusMenuItem() {
        let statusText = isServerRunning ? (isPaused ? "Paused" : "Running") : "Stopped"
        print("🔄 Updating status menu item: \(statusText)")
        statusMenuItem?.title = "Status: \(statusText)"
    }
    
    /// Updates the "Pause/Run" menu item
    func updatePauseRunMenuItem() {
        guard isServerRunning else {
            pauseRunMenuItem?.isHidden = true
            return
        }
        pauseRunMenuItem?.title = isPaused ? "Run" : "Pause"
        pauseRunMenuItem?.isHidden = false
    }
    
    /// Updates the "Start/Stop" menu item
    func updateStartStopMenuItem() {
        startStopMenuItem?.title = isServerRunning ? "Stop Server" : "Start Server"
    }
    
    /// Updates the IP address menu item
    func updateIpAddressMenuItem(port: Int? = nil) {
        guard let ipAddress = getPrimaryIPAddress(),
              let validPort = port, (1...65535).contains(validPort) else {
            ipAddressMenuItem?.title = "IP: none"
            return
        }
        ipAddressMenuItem?.title = "IP: \(ipAddress):\(validPort)"
    }
    
    /// Retrieves the primary IP address of the machine
    func getPrimaryIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        // Retrieve the interface addresses
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                
                // Filter for IPv4 and primary interface
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                   String(cString: interface.ifa_name) == "en0" {
                    var addr = interface.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &addr.sin_addr, buffer, socklen_t(INET_ADDRSTRLEN))
                    address = String(cString: buffer)
                    buffer.deallocate()
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    /// Displays a configuration error alert
    private func showConfigurationError() {
        print("❌ Missing configuration. Server will not start.")
        if let window = NSApp.keyWindow, !window.isKind(of: NSAlert.self) {
            showErrorAlert(message: """
            Missing configuration files or directories.
            Go to Settings and click Install to set up the environment.
            """)
        }
    }
    
    /// Updates UI after the server starts
    private func updateUIAfterServerStart(port: Int) {
        updatePauseRunMenuItem()
        updateStartStopMenuItem()
        updateStatusMenuItem()
        updateIpAddressMenuItem(port: port)
    }
    
    /// Resets the server state and updates the UI
    private func resetServerState() {
        server = nil
        isServerRunning = false
        isPaused = false
        updatePauseRunMenuItem()
        updateStartStopMenuItem()
        updateStatusMenuItem()
        updateIpAddressMenuItem()
    }
}
