import Vapor
import Translation

// Variable globale pour gérer l'état du serveur
var isWorking = false

func createServer(on port: Int, appDelegate: AppDelegate) throws -> Application {
    // Create a custom environment
    let env = Environment(name: "custom", arguments: ["vapor", "serve", "--port", "\(port)"])
    let app = Application(env)

    // Configure the server to bind to all interfaces
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port

    // Route for server status
    app.post("status") { req -> Response in
        if appDelegate.isPaused {
            let response = Response(status: .serviceUnavailable)
            try response.content.encode(["error": "paused"], as: .json)
            return response
        } else if isWorking {
            let response = Response(status: .ok)
            try response.content.encode(["status": "working"], as: .json)
            return response
        } else {
            let response = Response(status: .ok)
            try response.content.encode(["status": "waiting"], as: .json)
            return response
        }
    }

    // Route for translation
    app.post("translate") { req -> Response in
        // Check if the server is busy
        guard !isWorking else {
            let response = Response(status: .tooManyRequests)
            try response.content.encode(["error": "Server is busy. Try again later."], as: .json)
            return response
        }

        // Decode the request body
        let requestData = try req.content.decode(TranslationRequest.self)

        // Mark the server as working
        isWorking = true

        // Ensure isWorking is reset to false after processing
        defer {
            isWorking = false
        }

        // Perform the translation and handle errors
        do {
            let translationResult = try appDelegate.performTranslationWithScript(inputText: requestData.text)

            // Create and return the response
            let response = Response(status: .ok)
            try response.content.encode(translationResult, as: .json)
            return response
        } catch {
            // Handle errors
            let response = Response(status: .internalServerError)
            try response.content.encode(["error": "Translation failed", "details": "\(error)"], as: .json)
            return response
        }
    }

    print("🔧 Server configured on port \(port)")
    return app
}

// Structure to decode incoming request data
struct TranslationRequest: Content {
    let text: String
}

// Error for translation issues
enum TranslationError: Error {
    case invalidResult
}
