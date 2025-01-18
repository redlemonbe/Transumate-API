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
                    apiUsageSection // Updated Section for API Usage and Status/Error Explanation
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
        .onDrag {
            NSCursor.arrow.set()
            return NSItemProvider()
        }
        .textSelection(.enabled) // Enables text selection and copy-paste
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
                If you're feeling lost, here's what you can do:
                - Configure your server and API settings.
                - Manage project files and directories.
                - Allocate CPU resources efficiently.
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
                - Click "Start Server" to launch the server. Ensure the port is valid (1–65535).
                - Use "Pause" to temporarily halt operations.
                - Click "Stop Server" to terminate all operations. “Sometimes you gotta stop to go forward.”
                """)
                    .foregroundColor(.secondary)
                Text("Troubleshooting:")
                Text("""
                - If the server doesn’t start, check the port or ensure all required files are installed.
                - Paused? Click "Run" to resume operations.
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
                - Click "Install" to set up necessary directories and files.
                - If already installed, the button will be disabled to avoid redundant work.
                """)
                    .foregroundColor(.secondary)
                Text("File Deletion:")
                Text("""
                - Click "Delete" to remove all project directories.
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
                - Default: 20%. Increase for faster operations, but monitor your machine's limits.
                """)
                    .foregroundColor(.secondary)
                Text("CPU Overload Protection:")
                Text("""
                - The system monitors CPU usage in real-time.
                - If usage exceeds your allocated limit, operations will pause. “The needs of the many outweigh the needs of the few.”
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
                The Transumate API provides endpoints for text translation and summarization.
                Use these endpoints to interact with the server programmatically.
                """)
                    .foregroundColor(.secondary)

                Divider()

                // API Endpoints
                Text("Endpoints:")
                Text("""
                - **Base URL**: `http://<your-server-ip>:<port>/`
                - **POST /translate**: Submits text for translation. Requires a valid API key.
                - **GET /status**: Retrieves the server's current status.
                """)
                    .foregroundColor(.secondary)

                Divider()

                // Request Example
                Text("Request Example:")
                Text("""
                Endpoint: `/translate`
                Method: `POST`
                Headers:
                    - `Authorization: Bearer <API_KEY>`
                Body:
                {
                    "url": "https://example.com/some-article"
                }
                """)
                    .foregroundColor(.blue)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))

                Divider()

                // Response Example
                Text("Response Example:")
                Text("""
                {
                    "date": "2025-01-16T22:03:35+01:00",
                    "status": "ok",
                    "translated_title": "Translated version of the title.",
                    "keywords": {
                        "keyword_1": "key1",
                        "keyword_2": "key2",
                        "keyword_3": "key3",
                        "keyword_2": "key4",
                        "keyword_3": "key5"
                    },
                    "text": "Translated version of the text provided.",
                    "author": "Author of the original text",
                    "title": "Original title provided in the request"
                }
                """)
                    .foregroundColor(.blue)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))

                Divider()

                // Explanation of Response Fields
                Text("Explanation of Response Fields:")
                Text("""
                - **date**: Timestamp when the response was generated, in ISO 8601 format.
                - **status**: Indicates the operation's result:
                    - `ok`: The request was successful.
                    - `error`: An error occurred.
                - **translated_title**: The translated version of the title provided in the request.
                - **keywords**: A list of extracted keywords from the text, represented as key-value pairs.
                - **text**: The fully translated version of the input text.
                - **author**: The author of the original text (if provided).
                - **title**: The original title included in the request.
                """)
                    .foregroundColor(.secondary)

                Divider()

                // Error Handling
                Text("Common Errors:")
                Text("""
                - **Missing API key**: No API key was provided in the request header.
                - **Invalid API key**: The provided API key is incorrect.
                - **CPU overload**: CPU usage exceeded the allocated limit. The request is paused until usage decreases.
                - **Invalid request body**: The request payload is malformed or missing required fields.
                - **Unable to access the provided URL.
                """)
                    .foregroundColor(.red)

                Divider()

                // Notes
                Text("Additional Notes:")
                Text("""
                - Ensure the API key is configured in the server's settings.
                - The `Authorization` header is required for all endpoints except `/status`.
                - All dates are returned in ISO 8601 format.
                """)
                    .foregroundColor(.secondary)
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
