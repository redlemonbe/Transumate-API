import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var apiKey: String = ""
    @State private var port: String = "8080"
    @State private var cpuAllocation: Double = 20.0 // Default CPU allocation
    @State private var isHelpPresented: Bool = false // State to present HelpView
    
    var closeWindow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            Divider()
            serverStatusSection
            serverSettingsSection
            cpuAllocationSection
            fileManagerSection
            Spacer()
            footerSection
        }
        .padding()
        .frame(width: 500, height: 800)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10)
        .onAppear(perform: loadConfiguration)
        .sheet(isPresented: $isHelpPresented) {
            HelpView {
                isHelpPresented = false // Close HelpView
            }
        }
    }

    // MARK: - Header Section
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

    // MARK: - Server Status Section
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
                        appDelegate.togglePause()
                    }
                    .buttonStyle(BorderedButtonStyle())

                    Button(appDelegate.isServerRunning ? "Stop Server" : "Start Server") {
                        toggleServer()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top, 5)
            }
            .padding()
        }
    }

    // MARK: - Server Settings Section
    private var serverSettingsSection: some View {
        GroupBox(label: Label("Server Settings", systemImage: "server.rack")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("API Key:")
                    Spacer()
                    TextField("Enter API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
                    Button("Save Settings") {
                        saveConfiguration()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top, 5)
            }
            .padding()
        }
    }

    // MARK: - CPU Allocation Section
    private var cpuAllocationSection: some View {
        GroupBox(label: Label("CPU Allocation", systemImage: "cpu")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CPU Power Allocation:")
                    Spacer()
                    Text("\(Int(cpuAllocation))%")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                }
                Slider(value: $cpuAllocation, in: 0...100, step: 1)
                    .onChange(of: cpuAllocation) {
                        saveCPUAllocation()
                    }
            }
            .padding()
        }
    }

    // MARK: - File Manager Section
    private var fileManagerSection: some View {
        GroupBox(label: Label("File Manager", systemImage: "folder")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(appDelegate.directoryStatusMessage)
                    .foregroundColor(appDelegate.directoryStatusColor)
                HStack {
                    Text("Install Files:")
                    Spacer()
                    Button("Install") {
                        appDelegate.installFiles()
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(appDelegate.areFilesInstalled)
                }
                HStack {
                    Text("Delete Files:")
                    Spacer()
                    Button("Delete") {
                        appDelegate.deleteDirectories()
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(!appDelegate.areFilesInstalled)
                }
            }
            .padding()
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Button("Help") {
                    isHelpPresented = true // Open HelpView
                }
                .buttonStyle(BorderedButtonStyle())
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

    // MARK: - Helper Methods
    func getServerStatusText() -> String {
        appDelegate.isServerRunning ? (appDelegate.isPaused ? "Paused" : "Running") : "Stopped"
    }

    func getServerStatusColor() -> Color {
        appDelegate.isServerRunning ? (appDelegate.isPaused ? .orange : .green) : .red
    }

    func loadConfiguration() {
        let userDefaults = UserDefaults.standard
        apiKey = userDefaults.string(forKey: "APIKey") ?? UUID().uuidString
        port = userDefaults.string(forKey: "Port") ?? "8080"
        cpuAllocation = userDefaults.double(forKey: "CPUAllocation")
        if cpuAllocation == 0 { cpuAllocation = 20.0 } // Default 20% if no value saved
    }

    func regenerateApiKey() {
        apiKey = UUID().uuidString
        saveConfiguration()
    }

    func saveConfiguration() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(apiKey, forKey: "APIKey")
        userDefaults.set(port, forKey: "Port")
        print("✅ Configuration saved: API Key: \(apiKey), Port: \(port)")
    }

    func saveCPUAllocation() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(cpuAllocation, forKey: "CPUAllocation")
        print("✅ CPU Allocation saved: \(Int(cpuAllocation))%")
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
