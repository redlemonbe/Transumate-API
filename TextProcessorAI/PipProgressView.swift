import SwiftUI

struct PipProgressView: View {
    @State private var progress: Double = 0.0 // Progress value
    @State private var currentPackage: String = "Initializing installation..." // Current package being installed
    @State private var isInstalling: Bool = true // Installation status
    @State private var errorMessage: String? = nil // Error message
    @State private var isCancelled: Bool = false // Indicates if installation was cancelled

    let packages = ["requests", "numpy", "pandas", "scipy", "tqdm", "transformers",
                    "torch", "torchaudio", "torchvision", "goose3", "huggingface_hub",
                    "keybert", "langcodes"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Building Your Python Environment")
                .font(.title)
                .fontWeight(.bold)

            if let error = errorMessage {
                Text("Error: \(error)")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if !isInstalling && !isCancelled {
                Text("Installation completed successfully!")
                    .font(.headline)
                    .foregroundColor(.green)
            } else if isCancelled {
                Text("Installation was cancelled.")
                    .font(.headline)
                    .foregroundColor(.orange)
            } else {
                ProgressView(value: progress, total: Double(packages.count))
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()

                Text(currentPackage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Button(isInstalling ? "Stop" : "Close") {
                if isInstalling {
                    cancelInstallation()
                } else {
                    closeWindow()
                }
            }
            .buttonStyle(BorderedButtonStyle())
            .padding()
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            startInstallation()
        }
    }

    /// Starts the installation of packages
    func startInstallation() {
        DispatchQueue.global(qos: .background).async {
            for (index, package) in packages.enumerated() {
                if isCancelled {
                    DispatchQueue.main.async {
                        errorMessage = nil
                        currentPackage = "Installation cancelled."
                        isInstalling = false
                    }
                    return
                }

                DispatchQueue.main.async {
                    currentPackage = "Installing: \(package)"
                    progress = Double(index + 1)
                }
                let result = installPackage(package: package)
                if !result {
                    DispatchQueue.main.async {
                        currentPackage = "Failed to install: \(package)"
                        errorMessage = "Installation failed for \(package). Please check your environment."
                        isInstalling = false
                    }
                    return // Stop further installation if an error occurs
                }
                sleep(1) // Simulate installation delay
            }
            DispatchQueue.main.async {
                currentPackage = "Installation Completed"
                isInstalling = false
            }
        }
    }

    /// Cancels the installation process
    func cancelInstallation() {
        isCancelled = true
        isInstalling = false
    }

    /// Installs a single Python package
    /// - Parameter package: Name of the package to install
    /// - Returns: Boolean indicating success or failure
    func installPackage(package: String) -> Bool {
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let envDirectory = homePath.appendingPathComponent(".transumate")

        let pipCommand = "\(envDirectory.path)/bin/pip install \(package)"
        do {
            try executeShellCommand(pipCommand)
            return true
        } catch {
            return false
        }
    }

    /// Executes a shell command
    /// - Parameter command: Command to execute
    /// - Returns: Output of the command
    func executeShellCommand(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/zsh"
        process.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return String(data: data, encoding: .utf8) ?? ""
        } else {
            throw NSError(domain: "ShellCommandError", code: Int(process.terminationStatus), userInfo: nil)
        }
    }

    /// Closes the window
    func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

struct PipProgressView_Previews: PreviewProvider {
    static var previews: some View {
        PipProgressView()
    }
}
