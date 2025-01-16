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
    @Published var areFilesInstalled: Bool = false
    
    struct TranslationResponse: Content {
        let status: String
        let title: String
        let translated_title: String
        let author: String
        let date: String
        let keywords: [String: String]
        let text: String
    }
    
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
        let envDirectory = homePath.appendingPathComponent(".transumate")

        if FileManager.default.fileExists(atPath: envDirectory.path) {
            print("✅ Python environment already exists at: \(envDirectory.path)")
            return
        }

        let createEnvCommand = "python3 -m venv \(envDirectory.path)"

        do {
            try executeShellCommand(createEnvCommand)
            print("✅ Python environment created at: \(envDirectory.path)")
            // Launch the SwiftUI view for installation progress
            DispatchQueue.main.async {
                let pipProgressView = PipProgressView()
                let hostingController = NSHostingController(rootView: pipProgressView)
                let pipWindow = NSWindow(contentViewController: hostingController)
                pipWindow.title = "Python Package Installation" // Define the title
                pipWindow.styleMask = [.titled, .closable, .fullSizeContentView]
                pipWindow.makeKeyAndOrderFront(nil) // Bring to the front
                pipWindow.center() // Center the window
            }
        } catch {
            print("❌ Failed to create Python environment: \(error.localizedDescription)")
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
    
    func executeShellCommandwithresult(_ command: String) throws -> String {
        let process = Process()
        process.launchPath = "/bin/zsh" // Remplacez par /bin/bash ou autre si nécessaire
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ExecuteShellCommandError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode shell output"])
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Installs the Python environment, required directories, and files.
    func installFiles() {
        print("🔧 Installing Python environment, directories, and files...")
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let mainDirectory = homePath.appendingPathComponent(".transumate")
        let modelsDirectory = mainDirectory.appendingPathComponent("models")

        // Crée l'environnement Python en premier
        createPythonEnvironment()

        do {
            // Crée les répertoires nécessaires
            if !FileManager.default.fileExists(atPath: mainDirectory.path) {
                try FileManager.default.createDirectory(at: mainDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ Main directory created at: \(mainDirectory.path)")
            }
            if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
                try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ 'models' directory created at: \(modelsDirectory.path)")
            }

            // Copie les fichiers nécessaires
            try copyFile(from: "Translate", withExtension: "py", to: mainDirectory)

            areFilesInstalled = true // Met à jour l'état observable
            directoryStatusMessage = "Python environment, directories, and files successfully installed."
            directoryStatusColor = .green
            checkDirectories() // Vérifie les fichiers installés
        } catch {
            print("❌ Error during installation: \(error.localizedDescription)")
            directoryStatusMessage = "Error during installation: \(error.localizedDescription)"
            directoryStatusColor = .red
            areFilesInstalled = false
        }
    }

    /// Deletes the application's directories and environment.
    func deleteDirectories() {
        print("🗑 Deleting directories...")
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let mainDirectory = homePath.appendingPathComponent(".transumate")

        do {
            if FileManager.default.fileExists(atPath: mainDirectory.path) {
                // Arrête le serveur avant de supprimer les répertoires
                if isServerRunning {
                    print("🔄 Stopping the server before deleting directories...")
                    stopServer()
                }

                // Supprime récursivement les fichiers et répertoires
                try FileManager.default.removeItem(at: mainDirectory)

                directoryStatusMessage = "Directories and Python environment successfully deleted."
                directoryStatusColor = .green
                print("✅ Directories and Python environment deleted successfully.")
                areFilesInstalled = false // Met à jour l'état observable
                checkDirectories()
            } else {
                directoryStatusMessage = "Directories do not exist."
                directoryStatusColor = .red
                areFilesInstalled = false // Met à jour l'état observable
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

        // Vérifiez l'existence du dossier principal et du fichier requis
        let directoriesExist = FileManager.default.fileExists(atPath: mainDirectory.path)
        let filesExist = FileManager.default.fileExists(atPath: mainFile.path)

        areFilesInstalled = directoriesExist && filesExist // Met à jour l'état observable

        if areFilesInstalled {
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

// Extension of AppDelegate for translation logic
extension AppDelegate {
    /// Executes the Python translation script and returns the result.
    /// - Parameter inputText: The text to translate.
    /// - Returns: The result of the translation as a dictionary.
    private static var pythonProcess: Process? // Référence au processus Python

        /// Executes the Python translation script with process management.
        /// - Parameter inputText: The text to translate.
        /// - Returns: The result of the translation as a dictionary.
        func performTranslationWithScript(inputText: String) throws -> TranslationResponse {
            let scriptName = "Translate.py"

            // Path setup
            let homePath = FileManager.default.homeDirectoryForCurrentUser
            let envDirectory = homePath.appendingPathComponent(".transumate") // Environment directory
            let scriptPath = homePath.appendingPathComponent(".transumate/\(scriptName)") // Script path

            // Command to execute the Python script
            let pythonPath = "\(envDirectory.path)/bin/python"
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath.path, inputText]

            // Capture the output
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            // Save the process globally to allow termination
            AppDelegate.pythonProcess = process

            // Run the process
            try process.run()

            // Wait for the process to complete
            process.waitUntilExit()

            // Reset the process reference
            AppDelegate.pythonProcess = nil

            // Read the output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let result = String(data: outputData, encoding: .utf8) else {
                throw TranslationError.invalidResult
            }

            // Decode the JSON result from the script
            guard let data = result.data(using: .utf8) else {
                throw TranslationError.invalidResult
            }

            let translationResult = try JSONDecoder().decode(TranslationResponse.self, from: data)
            return translationResult
        }

        /// Terminates the currently running Python script.
        func terminatePythonScript() {
            if let process = AppDelegate.pythonProcess, process.isRunning {
                process.terminate() // Sends SIGTERM to the process
                AppDelegate.pythonProcess = nil
            }
        }
}
