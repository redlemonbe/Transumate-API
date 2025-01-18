import Vapor
import Foundation

// Global variable to manage the server's working state
var isWorking = false

/// Middleware for API key validation
struct APIKeyMiddleware: Middleware {
    let validAPIKey: String

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let apiKey = request.headers.bearerAuthorization?.token else {
            return makeUnauthorizedResponse(for: request, message: "Missing API key")
        }

        guard apiKey == validAPIKey else {
            return makeUnauthorizedResponse(for: request, message: "Invalid API key")
        }

        return next.respond(to: request)
    }

    private func makeUnauthorizedResponse(for request: Request, message: String) -> EventLoopFuture<Response> {
        let response = Response(status: .unauthorized)
        try? response.content.encode(["error": message], as: .json)
        return request.eventLoop.makeSucceededFuture(response)
    }
}

/// Creates and configures the Vapor server
func createServer(on port: Int, appDelegate: AppDelegate) throws -> Application {
    let env = Environment(name: "custom", arguments: ["vapor", "serve", "--port", "\(port)"])
    let app = Application(env)
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = port

    // Configure middleware
    guard let validAPIKey = UserDefaults.standard.string(forKey: "APIKey") else {
        fatalError("API key not set in UserDefaults")
    }
    app.middleware.use(APIKeyMiddleware(validAPIKey: validAPIKey))

    // Define routes
    setupRoutes(app, appDelegate: appDelegate)

    print("🔧 Server configured on port \(port)")
    return app
}

/// Defines application routes
func setupRoutes(_ app: Application, appDelegate: AppDelegate) {
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
        try response.content.encode([
            "status": status,
            "memory_used_gb": formatMemory(getMemoryUsage()["used"]),
            "memory_total_gb": formatMemory(getMemoryUsage()["total"]),
            "cpu_usage_percent": String(format: "%.2f", getCPUUsage()),
            "os": ProcessInfo.processInfo.operatingSystemVersionString
        ], as: .json)
        return response
    }

    app.post("translate") { req -> EventLoopFuture<Response> in
        if appDelegate.isPaused {
            return createErrorResponse(req, .serviceUnavailable, "The server is paused. The Python script was terminated.", ["status": "paused"])
        }

        guard !isWorking else {
            return createErrorResponse(req, .tooManyRequests, "The server is currently processing another request.", ["status": "busy"])
        }

        let currentCPUUsage = getCPUUsage()
        let cpuAllocationLimit = UserDefaults.standard.double(forKey: "CPUAllocation")
        if currentCPUUsage >= cpuAllocationLimit {
            return createErrorResponse(
                req,
                .serviceUnavailable,
                "The server CPU usage is too high. The translation script was not executed.",
                [
                    "status": "cpu_overload",
                    "cpu_usage_percent": String(format: "%.2f", currentCPUUsage),
                    "cpu_allocation_limit": String(format: "%.2f", cpuAllocationLimit)
                ]
            )
        }

        let requestData: TranslationRequest
        do {
            requestData = try req.content.decode(TranslationRequest.self)
        } catch {
            return createErrorResponse(req, .badRequest, "Invalid request body.", ["details": "\(error)"])
        }

        isWorking = true
        let promise = req.eventLoop.makePromise(of: Response.self)

        DispatchQueue.global().async {
            defer {
                DispatchQueue.main.async { isWorking = false }
            }

            do {
                let translationResult = try appDelegate.performTranslationWithScript(inputText: requestData.text)
                let response = Response(status: .ok)
                try response.content.encode(translationResult, as: .json)
                promise.succeed(response)
            } catch {
                promise.fail(TranslationError(message: "Translation failed. \(error)"))
            }
        }

        let timeoutFuture = req.eventLoop.scheduleTask(in: .seconds(120)) {
            appDelegate.terminatePythonScript()
            promise.fail(TranslationError(message: "Translation request timed out."))
        }

        return promise.futureResult
            .always { _ in timeoutFuture.cancel() }
            .flatMapError { error in
                return createErrorResponse(req, .internalServerError, "\(error)")
            }
    }
}

/// Utility function to create a formatted error response
func createErrorResponse(
    _ req: Request,
    _ status: HTTPResponseStatus,
    _ message: String,
    _ additionalData: [String: Any] = [:]
) -> EventLoopFuture<Response> {
    let response = Response(status: status)
    var baseData: [String: Any] = ["message": message]
    baseData.merge(additionalData) { _, new in new }

    do {
        // Encode the dictionary as JSON using JSONSerialization
        let jsonData = try JSONSerialization.data(withJSONObject: baseData, options: [])
        response.body = .init(data: jsonData)
        response.headers.replaceOrAdd(name: .contentType, value: "application/json")
    } catch {
        // Handle JSON encoding failure
        let fallbackResponse = Response(status: .internalServerError)
        fallbackResponse.body = .init(string: "{\"error\": \"Failed to encode JSON\"}")
        fallbackResponse.headers.replaceOrAdd(name: .contentType, value: "application/json")
        return req.eventLoop.makeSucceededFuture(fallbackResponse)
    }

    return req.eventLoop.makeSucceededFuture(response)
}


/// Helper to format memory values
func formatMemory(_ value: Double?) -> String {
    guard let value = value else { return "0.00" }
    return String(format: "%.2f", value)
}

/// Get memory usage
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

/// Get CPU usage
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

/// Request structure for translation
struct TranslationRequest: Content {
    let text: String
}

/// Custom error for translation-related issues
struct TranslationError: Error {
    let message: String
}
