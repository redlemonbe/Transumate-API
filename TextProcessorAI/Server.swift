import Vapor
import Foundation

// Global variable to manage the server's working state
var isWorking = false

/// Error type for translation-specific issues
struct TranslationError: Error, Codable {
    let message: String
}

/// Request structure for translation
struct TranslateRequest: Content {
    let url: String
}

/// Middleware for API key validation
struct APIKeyMiddleware: Middleware {
    let validAPIKey: String

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let apiKey = request.headers.bearerAuthorization?.token else {
            return createErrorResponse(request, .unauthorized, "Missing API key")
        }

        guard apiKey == validAPIKey else {
            return createErrorResponse(request, .unauthorized, "Invalid API key")
        }

        return next.respond(to: request)
    }
}

/// Creates and configures the Vapor server
func createServer(on port: Int, appDelegate: AppDelegate) throws -> Application {
    let env = Environment(name: "custom", arguments: ["vapor", "serve", "--port", "\(port)"])
    let app = Application(env)
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port

    guard let validAPIKey = UserDefaults.standard.string(forKey: "APIKey") else {
        fatalError("API key not set in UserDefaults")
    }

    app.middleware.use(APIKeyMiddleware(validAPIKey: validAPIKey))
    setupRoutes(app, appDelegate: appDelegate)

    print("🔧 Server configured on port \(port)")
    return app
}

/// Defines application routes
func setupRoutes(_ app: Application, appDelegate: AppDelegate) {
    // Status route
    app.post("status") { req -> Response in
        let status = appDelegate.isPaused ? "paused" : (isWorking ? "busy" : "ready")

        let response = Response(status: .ok)
        try response.content.encode([
            "status": status,
            "memory_used_gb": formatMemory(getMemoryUsage()["used"]),
            "memory_total_gb": formatMemory(getMemoryUsage()["total"]),
            "cpu_usage_percent": String(format: "%.2f", getCPUUsage()),
            "os": ProcessInfo.processInfo.operatingSystemVersionString
        ], as: .json)
        return response
    }

    // Translate route
    app.post("translate") { req -> EventLoopFuture<Response> in
        guard !appDelegate.isPaused else {
            return createErrorResponse(req, .serviceUnavailable, "The server is paused.")
        }

        guard !isWorking else {
            return createErrorResponse(req, .tooManyRequests, "The server is currently processing another request.")
        }

        let currentCPUUsage = getCPUUsage()
        let cpuAllocationLimit = UserDefaults.standard.double(forKey: "CPUAllocation")
        guard currentCPUUsage < cpuAllocationLimit else {
            return createErrorResponse(req, .serviceUnavailable, "CPU usage too high.", [
                "cpu_usage_percent": String(format: "%.2f", currentCPUUsage),
                "cpu_allocation_limit": String(format: "%.2f", cpuAllocationLimit)
            ])
        }

        let requestData: TranslateRequest
        do {
            requestData = try req.content.decode(TranslateRequest.self)
        } catch {
            return createErrorResponse(req, .badRequest, "Invalid request body.", ["details": "\(error)"])
        }

        guard let url = URL(string: requestData.url), url.scheme?.hasPrefix("http") == true else {
            return createErrorResponse(req, .badRequest, "Invalid or unreachable URL.")
        }

        return validateURL(url, on: req.eventLoop).flatMap { isReachable in
            guard isReachable else {
                return createErrorResponse(req, .badRequest, "URL is unreachable.")
            }

            return executeTranslation(url: url, req: req, appDelegate: appDelegate)
        }
    }
}

/// Validates the URL by sending a lightweight `HEAD` request
func validateURL(_ url: URL, on eventLoop: EventLoop) -> EventLoopFuture<Bool> {
    let promise = eventLoop.makePromise(of: Bool.self)
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"

    URLSession.shared.dataTask(with: request) { _, response, _ in
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            promise.succeed(true)
        } else {
            promise.succeed(false)
        }
    }.resume()

    return promise.futureResult
}

/// Executes the translation script asynchronously
func executeTranslation(url: URL, req: Request, appDelegate: AppDelegate) -> EventLoopFuture<Response> {
    isWorking = true
    let promise = req.eventLoop.makePromise(of: Response.self)

    DispatchQueue.global().async {
        defer { DispatchQueue.main.async { isWorking = false } }

        do {
            let result = try appDelegate.performTranslationWithScript(inputText: url.absoluteString)
            let response = Response(status: .ok)
            try response.content.encode(result, as: .json)
            promise.succeed(response)
        } catch {
            promise.fail(TranslationError(message: "Translation failed: \(error.localizedDescription)"))
        }
    }

    let timeoutFuture = req.eventLoop.scheduleTask(in: .seconds(120)) {
        appDelegate.terminatePythonScript()
        promise.fail(TranslationError(message: "Translation timed out."))
    }

    return promise.futureResult
        .always { _ in timeoutFuture.cancel() }
        .flatMapError { error in
            if let translationError = error as? TranslationError {
                return createErrorResponse(req, .internalServerError, translationError.message)
            }
            return createErrorResponse(req, .internalServerError, "An unexpected error occurred.")
        }
}

/// Utility function to create a formatted error response
func createErrorResponse(_ req: Request, _ status: HTTPResponseStatus, _ message: String, _ additionalData: [String: Any] = [:]) -> EventLoopFuture<Response> {
    let response = Response(status: status)
    var data: [String: Any] = ["status": "error", "message": message]
    data.merge(additionalData) { _, new in new }

    do {
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
        response.body = .init(data: jsonData)
        response.headers.replaceOrAdd(name: .contentType, value: "application/json")
    } catch {
        response.body = .init(string: "{\"status\": \"error\", \"message\": \"Failed to encode error response\"}")
        response.headers.replaceOrAdd(name: .contentType, value: "application/json")
    }

    return req.eventLoop.makeSucceededFuture(response)
}

/// Helper to format memory values
func formatMemory(_ value: Double?) -> String {
    return String(format: "%.2f", value ?? 0.0)
}

/// Returns memory usage information
func getMemoryUsage() -> [String: Double] {
    var memoryStats: [String: Double] = [:]

    // Get system-wide memory statistics
    var vmStats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vmStats) / MemoryLayout<integer_t>.size)
    let hostPort = mach_host_self()

    let result = withUnsafeMutablePointer(to: &vmStats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
        }
    }

    if result == KERN_SUCCESS {
        // Page size (in bytes)
        let pageSize = vm_kernel_page_size
        
        // Memory used (active + inactive + wired)
        let usedMemory = Double(vmStats.active_count + vmStats.inactive_count + vmStats.wire_count) * Double(pageSize)
        
        // Total physical memory
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        // Assign values in gigabytes (GB)
        memoryStats["used"] = usedMemory / 1024 / 1024 / 1024 // Convert to GB
        memoryStats["total"] = totalMemory / 1024 / 1024 / 1024 // Convert to GB
    } else {
        // Default to 0 if fetching statistics fails
        memoryStats["used"] = 0.0
        memoryStats["total"] = 0.0
    }

    return memoryStats
}

func getCPUUsage() -> Double {
    var cpuLoad = host_cpu_load_info()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    
    let result = withUnsafeMutablePointer(to: &cpuLoad) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
        }
    }
    
    guard result == KERN_SUCCESS else { return 0.0 }
    
    let user = Double(cpuLoad.cpu_ticks.0) // User time
    let system = Double(cpuLoad.cpu_ticks.1) // System time
    let idle = Double(cpuLoad.cpu_ticks.2) // Idle time
    let nice = Double(cpuLoad.cpu_ticks.3) // Nice time

    let total = user + system + idle + nice
    let usage = ((user + system + nice) / total) * 100.0
    
    return usage
}
