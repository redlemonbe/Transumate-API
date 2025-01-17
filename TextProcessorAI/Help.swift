import SwiftUI

struct HelpView: View {
    var closeWindow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            Divider()

            // Help Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    generalHelpSection
                    serverHelpSection
                    fileManagerHelpSection
                    cpuHelpSection
                    apiUsageSection // New Section for API Usage
                }
                .padding()
            }

            Spacer()

            // Footer
            footerSection
        }
        .padding()
        .frame(width: 600, height: 750)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 5) {
            Text("Transumate Help Center")
                .font(.title)
                .fontWeight(.semibold)
            Text("“Help is always given at Hogwarts to those who ask for it.”")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - General Help Section
    private var generalHelpSection: some View {
        GroupBox(label: Label("General", systemImage: "info.circle")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Welcome to Transumate! Your trusted companion for text translation and summarization.")
                Text("""
                If you're feeling lost, don't panic! Here's an overview of what you can do:
                - Configure your server and API settings.
                - Manage files and directories for your project.
                - Allocate CPU resources like a pro.
                Remember, “Not all those who wander are lost.”
                """)
                    .foregroundColor(.secondary)
                    .italic()
            }
            .padding()
        }
    }

    // MARK: - Server Help Section
    private var serverHelpSection: some View {
        GroupBox(label: Label("Server", systemImage: "server.rack")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Starting and Stopping the Server:")
                Text("""
                - Click "Start Server" to fire up the server. Make sure the port is valid (1–65535).
                - Use "Pause" to temporarily halt operations without shutting down.
                - Click "Stop Server" to terminate all operations. “Sometimes you gotta stop to go forward.”
                """)
                    .foregroundColor(.secondary)
                Text("Troubleshooting:")
                Text("""
                - If the server doesn't start, check the port or ensure all required files are installed.
                - Paused? Don't worry. Click "Run" to resume operations.
                """)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    // MARK: - File Manager Help Section
    private var fileManagerHelpSection: some View {
        GroupBox(label: Label("File Manager", systemImage: "folder")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("File Installation:")
                Text("""
                - Click "Install" to set up the necessary directories and files.
                - Already installed? The button will disable itself. We’re not fans of redundant work either.
                """)
                    .foregroundColor(.secondary)
                Text("File Deletion:")
                Text("""
                - Click "Delete" to remove the project directories and start fresh.
                - Warning: This action is irreversible. “With great power comes great responsibility.”
                """)
                    .foregroundColor(.red)
            }
            .padding()
        }
    }

    // MARK: - CPU Allocation Help Section
    private var cpuHelpSection: some View {
        GroupBox(label: Label("CPU Allocation", systemImage: "cpu")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adjusting CPU Power:")
                Text("""
                - Use the slider to allocate CPU resources (0–100%).
                - Default is 20%. Increase this value for faster operations, but be mindful of your machine's limits.
                """)
                    .foregroundColor(.secondary)
                Text("CPU Overload Protection:")
                Text("""
                - The system monitors CPU usage in real-time.
                - If usage exceeds your allocated limit, operations will pause to prevent overload. “The needs of the many outweigh the needs of the few.”
                """)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    // MARK: - API Usage Section
    private var apiUsageSection: some View {
        GroupBox(label: Label("API Usage", systemImage: "globe")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Using the API:")
                Text("""
                The API provides endpoints for text translation and summarization. Here’s how to use it:
                - Base URL: `http://<your-server-ip>:<port>/`
                - Supported Endpoints:
                    - **`POST /translate`**: Submit text for translation.
                    - **`GET /status`**: Check the server's status.
                """)
                    .foregroundColor(.secondary)
                Text("Example Request:")
                Text("""
                - Endpoint: `/translate`
                - Method: `POST`
                - Body: `{ "text": "Your text here" }`
                - Headers: Include your API Key as `Authorization: Bearer <API_KEY>`.
                """)
                    .foregroundColor(.secondary)
                Text("Response Example:")
                Text("""
                {
                    "status": "ok",
                    "translated_text": "Translated text here.",
                    "source_language": "en",
                    "target_language": "fr"
                }
                """)
                    .foregroundColor(.blue)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
            }
            .padding()
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button("Close") {
                    closeWindow()
                }
                .buttonStyle(BorderedButtonStyle())
            }
            .padding(.bottom, 10)

            Text("Transumate v0.1 • Created by Dyscode")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}
