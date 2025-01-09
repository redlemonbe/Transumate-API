import Vapor

// Définition de l'objet User conforme à Content
struct User: Content {
    let id: Int
    let name: String
}

struct JSONResponses {
    // Réponse pour "/status"
    static func status(req: Request) -> Response {
        let response = Response(status: .ok)
        try? response.content.encode(["status": "ok"], as: .json)
        return response
    }

    // Réponse pour "/info"
    static func info(req: Request) -> Response {
        let response = Response(status: .ok)
        try? response.content.encode(["version": "1.0", "author": "Your Name"], as: .json)
        return response
    }

    // Réponse pour "/users"
    static func users(req: Request) -> Response {
        // Liste des utilisateurs comme objets User
        let users = [
            User(id: 1, name: "Alice"),
            User(id: 2, name: "Bob")
        ]
        
        // Création de la réponse JSON
        let response = Response(status: .ok)
        do {
            // Encodage JSON avec Vapor
            try response.content.encode(["users": users], as: .json)
        } catch {
            // Gestion des erreurs d'encodage
            print("❌ Failed to encode users: \(error.localizedDescription)")
        }
        return response
    }
}
