import Vapor
import Translation

func createServer(on port: Int, appDelegate: AppDelegate) throws -> Application {
    // Create a custom environment
    let env = Environment(name: "custom", arguments: ["vapor", "serve", "--port", "\(port)"])
    let app = Application(env)

    // Configure the server to bind to all interfaces
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port

    // Route for server status
    app.get("status") { req -> Response in
        if appDelegate.isPaused {
            let response = Response(status: .serviceUnavailable)
            try response.content.encode(["error": "paused"], as: .json)
            return response
        } else {
            let response = Response(status: .ok)
            try response.content.encode(["status": "waiting"], as: .json)
            return response
        }
    }

    // Example of additional routes
    app.get("info") { req -> Response in
        let response = Response(status: .ok)
        try response.content.encode(["version": "0.1", "author": "Dyscode"], as: .json)
        return response
    }

    print("🔧 Server configured on port \(port)")
    return app
}


