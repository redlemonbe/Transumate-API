import Vapor
import Translation
import Foundation


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
        
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        let osName = ProcessInfo.processInfo.operatingSystemVersionString

        let response = Response(status: .ok)
        try response.content.encode([
            "status": status,
            "memory_used_gb": String(format: "%.2f", memoryUsage["used"] ?? 0.0), // Total memory used in GB
            "memory_total_gb": String(format: "%.2f", memoryUsage["total"] ?? 0.0), // Total system memory in GB
            "cpu_usage_percent": String(format: "%.2f", cpuUsage), // CPU usage as percentage
            "os": osName
        ], as: .json)
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

/// Returns CPU usage as a percentage
import Foundation

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
