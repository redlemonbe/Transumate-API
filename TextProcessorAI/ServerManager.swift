import Foundation
import AppKit
import Vapor
import Network


extension AppDelegate {
    
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
}
