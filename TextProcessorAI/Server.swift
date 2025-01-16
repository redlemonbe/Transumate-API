import Vapor
import Translation

// Global variable to manage the server's working state
var isWorking = false

/// Creates and configures the Vapor server
func createServer(on port: Int, appDelegate: AppDelegate) throws -> Application {
    let env = Environment(name: "custom", arguments: ["vapor", "serve", "--port", "\(port)"])
    let app = Application(env)
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port

    // Server status route
    app.post("status") { req -> Response in
        let status: String
        if appDelegate.isPaused {
            status = "paused"
        } else if isWorking {
            status = "busy"
        } else {
            status = "ready"
        }
        let response = Response(status: .ok)
        try response.content.encode(["status": status], as: .json)
        return response
    }

    // Translation route
    app.post("translate") { req -> EventLoopFuture<Response> in
        // Handle paused state
        if appDelegate.isPaused {
            appDelegate.terminatePythonScript() // Stop the Python script if paused
            let response = Response(status: .serviceUnavailable)
            try? response.content.encode([
                "status": "paused",
                "message": "The server is paused. The Python script was terminated."
            ], as: .json)
            return req.eventLoop.makeSucceededFuture(response)
        }

        // Handle busy state
        guard !isWorking else {
            let response = Response(status: .tooManyRequests)
            try? response.content.encode([
                "status": "busy",
                "message": "The server is currently processing another request. Please try again later."
            ], as: .json)
            return req.eventLoop.makeSucceededFuture(response)
        }

        // Decode the request body
        let requestData: TranslationRequest
        do {
            requestData = try req.content.decode(TranslationRequest.self)
        } catch {
            let response = Response(status: .badRequest)
            try? response.content.encode([
                "status": "error",
                "message": "Invalid request body.",
                "details": "\(error)"
            ], as: .json)
            return req.eventLoop.makeSucceededFuture(response)
        }

        // Mark the server as working
        isWorking = true

        // Create a promise to handle the script execution
        let promise = req.eventLoop.makePromise(of: Response.self)

        // Dispatch work asynchronously
        DispatchQueue.global().async {
            defer {
                // Ensure `isWorking` is reset when work completes
                DispatchQueue.main.async {
                    isWorking = false
                }
            }

            do {
                // Execute the Python translation script
                let translationResult = try appDelegate.performTranslationWithScript(inputText: requestData.text)

                // Create a success response
                let response = Response(status: .ok)
                try response.content.encode(translationResult, as: .json)
                promise.succeed(response)
            } catch {
                // Handle script execution errors
                let response = Response(status: .internalServerError)
                try? response.content.encode([
                    "status": "error",
                    "message": "Translation failed.",
                    "details": "\(error)"
                ], as: .json)
                promise.fail(error)
            }
        }

        // Apply a timeout of 2 minutes
        let timeoutFuture = req.eventLoop.scheduleTask(in: .seconds(120)) {
            appDelegate.terminatePythonScript() // Stop Python script on timeout
            let response = Response(status: .gatewayTimeout)
            try? response.content.encode([
                "status": "timeout",
                "message": "Translation request timed out. The Python script was terminated."
            ], as: .json)
            promise.fail(Abort(.gatewayTimeout, reason: "Translation script timed out"))
            return response
        }

        // Return the first result: either the promise succeeds or the timeout triggers
        return promise.futureResult.flatMap { result in
            timeoutFuture.cancel() // Cancel the timeout if work completes
            return req.eventLoop.makeSucceededFuture(result)
        }
    }

    print("🔧 Server configured on port \(port)")
    return app
}

// Structure for decoding incoming request data
struct TranslationRequest: Content {
    let text: String
}

// Error enum for translation issues
enum TranslationError: Error {
    case invalidResult
}
