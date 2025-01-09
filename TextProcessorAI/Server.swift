import Vapor
import Translation

func createServer(on port: Int, appDelegate: AppDelegate) throws -> Application {
    // Créez un nouvel environnement isolé
    let env = Environment(name: "custom", arguments: ["vapor", "serve", "--port", "\(port)"])
    let app = Application(env)

    // Route pour le statut du serveur
        app.get("status") { req -> Response in
            let response = Response(status: .ok)
            try response.content.encode(["status": !appDelegate.isPaused], as: .json)
            return response
        }

        // Exemple d'autres routes bloquées si en pause
        app.get("info") { req -> Response in
            if !appDelegate.isPaused {
                let response = Response(status: .serviceUnavailable)
                try response.content.encode(["error": "Server is paused"], as: .json)
                return response
            }
            let response = Response(status: .ok)
            try response.content.encode(["version": "0.1", "author": "Dyscode"], as: .json)
            return response
        }
    
        app.http.server.configuration.port = port
        print("🔧 Server configured on port \(port)")
        return app
}


