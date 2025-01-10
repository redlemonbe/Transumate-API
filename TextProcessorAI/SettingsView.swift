import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var apiKey: String = ""
    @State private var port: String = "8080"
    var closeWindow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header Section
            headerSection

            Divider()

            // Server Status Section
            serverStatusSection

            // Server Settings Section
            serverSettingsSection

            //File Manager
            fileManagerSection
            
            Spacer()

            // Footer Section
            footerSection
        }
        .padding()
        .frame(width: 500, height: 650)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10)
        .onAppear(perform: loadConfiguration)
    }
  
    private var fileManagerSection: some View {
        GroupBox(label: Label("File Manager", systemImage: "folder")) {
            VStack(alignment: .leading, spacing: 10) {
                // Status Message
                Text(appDelegate.directoryStatusMessage)
                    .foregroundColor(appDelegate.directoryStatusColor)
                    .padding(.bottom, 5)
                
                // Create Directory Section
                HStack {
                    Text("Install Files:")
                    Spacer()
                    Button("Install") {
                        appDelegate.installFiles()
                        //appDelegate.createPythonEnvironment() // Crée l'environnement Python
                        appDelegate.executePythonScript("Install_swift.py") // Exécute le script Python Translate.py
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                
                // Delete Directory Section
                HStack {
                    Text("Delete Files:")
                    Spacer()
                    Button("Delete") {
                        appDelegate.deleteDirectories()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }
            .padding()
            .onAppear {
                appDelegate.checkDirectories()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 5) {
            Text("Transumate API")
                .font(.title)
                .fontWeight(.semibold)
            Text("- Server Configuration -")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    private var serverStatusSection: some View {
        GroupBox(label: Label("Server Status", systemImage: "bolt.fill")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text(getServerStatusText())
                        .foregroundColor(getServerStatusColor())
                        .fontWeight(.bold)
                }
                HStack {
                    Spacer()
                    Button(appDelegate.isPaused ? "Run" : "Pause") {
                        togglePauseRun()
                    }
                    .buttonStyle(BorderedButtonStyle())

                    Button(appDelegate.isServerRunning ? "Stop Server" : "Start Server") {
                        if appDelegate.isServerRunning {
                            appDelegate.stopServer()
                        } else {
                            guard let portInt = Int(port), (1...65535).contains(portInt) else {
                                print("❌ Invalid port")
                                return
                            }
                            appDelegate.startServer(on: portInt)
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top, 5)
            }
            .padding()
        }
    }

    private var serverSettingsSection: some View {
        GroupBox(label: Label("Server Settings", systemImage: "server.rack")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("API Key:")
                    Spacer()
                    TextField("Enter API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textSelection(.enabled)
                    Button("Regenerate") {
                        regenerateApiKey()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                HStack {
                    Text("Server Port:")
                    Spacer()
                    TextField("8080", text: $port)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
                HStack {
                    Spacer()
                    Button("Save Settings", action: saveConfiguration)
                        .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top, 5)
            }
            .padding()
        }
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack {

                Spacer()

                Button("Close") {
                    closeWindow()
                }
                .buttonStyle(BorderedButtonStyle())
                Button("Quit Application") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(BorderedButtonStyle())
            }
            .padding(.bottom, 10)

            Text("Created by Dyscode • Text Translation & Summarization By API • Version 0.1")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    func getServerStatusText() -> String {
        if appDelegate.isServerRunning {
            return appDelegate.isPaused ? "Paused" : "Running"
        } else {
            return "Stopped"
        }
    }

    func getServerStatusColor() -> Color {
        if appDelegate.isServerRunning {
            return appDelegate.isPaused ? .orange : .green
        } else {
            return .red
        }
    }

    func togglePauseRun() {
        appDelegate.togglePause()
    }

    func loadConfiguration() {
        let userDefaults = UserDefaults.standard
        if let savedApiKey = userDefaults.string(forKey: "APIKey") {
            apiKey = savedApiKey
        } else {
            apiKey = UUID().uuidString
            saveConfiguration()
            print("✅ API Key generated: \(apiKey)")
        }
        port = userDefaults.string(forKey: "Port") ?? "8080"
    }

    func regenerateApiKey() {
        apiKey = UUID().uuidString
        saveConfiguration()
        print("🔄 API Key regenerated: \(apiKey)")
    }

    func saveConfiguration() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(apiKey, forKey: "APIKey")
        userDefaults.set(port, forKey: "Port")
        print("✅ Configuration saved: API Key: \(apiKey), Port: \(port)")

        if appDelegate.isServerRunning {
            print("🔄 Restarting server with new configuration...")
            appDelegate.stopServer()
        }
        guard let portInt = Int(port), (1...65535).contains(portInt) else {
            print("❌ Invalid port, server not restarted.")
            return
        }
        appDelegate.startServer(on: portInt)
    }

    func toggleServer() {
        if appDelegate.isServerRunning {
            appDelegate.stopServer()
        } else {
            saveConfiguration()
            guard let portInt = Int(port), (1...65535).contains(portInt) else {
                print("❌ Invalid port")
                return
            }
            appDelegate.startServer(on: portInt)
        }
    }
}
