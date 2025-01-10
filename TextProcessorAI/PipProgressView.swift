import SwiftUI
import Foundation

let MODEL_FILES: [String: [String]] = [
    "Helsinki-NLP/opus-mt-mul-en": [
        "config.json",
        "pytorch_model.bin",
        "tokenizer_config.json",
        "source.spm",
        "target.spm",
        "vocab.json",
    ],
    "facebook/bart-large-cnn": [
        "config.json",
        "model.safetensors",
        "generation_config.json",
        "vocab.json",
        "merges.txt",
        "tokenizer.json",
    ],
]

struct PipProgressView: View {
    @State private var progress: Double = 0.0
    @State private var currentPackage: String = "Initializing installation..."
    @State private var isInstalling: Bool = true
    @State private var errorMessage: String? = nil
    @State private var isCancelled: Bool = false
    @State private var isDownloading: Bool = false
    @State private var currentFile: String = "" // Fichier en cours de téléchargement
    @State private var fileDownloadProgress: Double = 0.0 // Progrès pour un seul fichier
    @State private var downloadedFiles: Int = 0
    private var taskObserver: NSKeyValueObservation?
    
    let packages = ["requests", "numpy", "pandas", "scipy", "tqdm", "transformers",
                    "torch", "torchaudio", "torchvision", "goose3", "huggingface_hub",
                    "keybert", "langcodes", "sentencepiece", "sacremoses", "urllib3<2.0"]
    
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
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()
                
                Text(currentPackage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if isDownloading {
                    Text(currentFile)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
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
    
    func startInstallation() {
        DispatchQueue.global(qos: .background).async {
            for (index, package) in packages.enumerated() {
                if isCancelled { break }
                DispatchQueue.main.async {
                    currentPackage = "Installing: \(package)"
                    progress = Double(index + downloadedFiles) / Double(packages.count + totalModelFileCount())
                }
                let result = installPackage(package: package)
                if !result {
                    DispatchQueue.main.async {
                        errorMessage = "Installation failed for \(package)."
                        isInstalling = false
                    }
                    return
                }
            }
            
            if !isCancelled {
                DispatchQueue.main.async {
                    currentPackage = "Downloading model files..."
                    isDownloading = true
                }
                downloadModelFiles { error in
                    DispatchQueue.main.async {
                        isDownloading = false
                        if let error = error {
                            errorMessage = error
                            currentPackage = "Error downloading models."
                        } else {
                            currentPackage = "All tasks completed!"
                        }
                        isInstalling = false
                    }
                }
            }
        }
    }
    
    func cancelInstallation() {
        isCancelled = true
        isInstalling = false
    }
    
    func installPackage(package: String) -> Bool {
        let homePath = FileManager.default.homeDirectoryForCurrentUser
        let envDirectory = homePath.appendingPathComponent(".transumate")
        let pipPath = envDirectory.appendingPathComponent("bin/pip")
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: pipPath.path)
        process.arguments = ["install", package]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("Error executing pip command for \(package): \(error)")
            return false
        }
    }
    
    func downloadModelFiles(updateErrorMessage: @escaping (String?) -> Void) {
        let modelBaseURL = "https://huggingface.co"
        let modelDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".transumate/models")
        
        do {
            if !FileManager.default.fileExists(atPath: modelDir.path) {
                try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            DispatchQueue.main.async {
                updateErrorMessage("Failed to create model directory: \(error.localizedDescription)")
            }
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            var totalDownloadedBytes = 0.0
            let totalFiles = self.totalModelFileCount()
            
            for (modelName, files) in MODEL_FILES {
                let modelPath = modelDir.appendingPathComponent(modelName)
                do {
                    if !FileManager.default.fileExists(atPath: modelPath.path) {
                        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true, attributes: nil)
                    }
                    
                    for file in files {
                        let fileURL = URL(string: "\(modelBaseURL)/\(modelName)/resolve/main/\(file)")!
                        let destination = modelPath.appendingPathComponent(file)
                        
                        DispatchQueue.main.async {
                            self.currentPackage = "Downloading model: \(modelName)"
                            self.currentFile = file
                        }
                        
                        let semaphore = DispatchSemaphore(value: 0)
                        downloadFile(from: fileURL, to: destination) { progress, speed in
                            DispatchQueue.main.async {
                                self.fileDownloadProgress = progress
                            }
                        } completion: { result in
                            if case .failure(let error) = result {
                                updateErrorMessage("Error downloading \(file): \(error.localizedDescription)")
                            }
                            DispatchQueue.main.async {
                                self.downloadedFiles += 1
                                self.progress = Double(self.packages.count + self.downloadedFiles) / Double(self.packages.count + totalFiles)
                            }
                            semaphore.signal()
                        }
                        semaphore.wait()
                    }
                } catch {
                    DispatchQueue.main.async {
                        updateErrorMessage("Error creating directory for \(modelName): \(error.localizedDescription)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                updateErrorMessage(nil)
            }
        }
    }
    
    func downloadFile(
        from url: URL,
        to destination: URL,
        progressHandler: @escaping (Double, String) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(NSError(domain: "DownloadError", code: -1, userInfo: nil)))
                return
            }
            
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: tempURL, to: destination)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func closeWindow() {
        NSApp.keyWindow?.close()
    }
    
    func totalModelFileCount() -> Int {
        MODEL_FILES.values.reduce(0) { $0 + $1.count }
    }
}
