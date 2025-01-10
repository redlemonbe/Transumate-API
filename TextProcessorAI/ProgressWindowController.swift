import Cocoa

class ProgressWindowController: NSWindowController {
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var okButton: NSButton!
    
    var totalPackages: Int = 0
    var currentPackageIndex: Int = 0
    
    override func windowDidLoad() {
        super.windowDidLoad()
        okButton.isEnabled = false
        progressBar.minValue = 0
        progressBar.maxValue = Double(totalPackages)
        progressBar.doubleValue = 0
    }
    
    func updateProgress(packageName: String, currentIndex: Int) {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = "Installing: \(packageName) (\(currentIndex) of \(self.totalPackages))"
            self.progressBar.doubleValue = Double(currentIndex)
        }
    }
    
    func showError(message: String) {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = "❌ Error: \(message)"
            self.okButton.isEnabled = true
        }
    }
    
    func installationCompleted() {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = "✅ Installation completed!"
            self.okButton.isEnabled = true
        }
    }
    
    @IBAction func okButtonClicked(_ sender: NSButton) {
        self.window?.close()
    }
}
