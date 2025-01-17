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
func getCPUUsage() -> Double {
    var threadsCount: mach_msg_type_number_t = 0
    var threadList: thread_act_array_t?
    let result = task_threads(mach_task_self_, &threadList, &threadsCount)
    
    defer {
        if let threadList = threadList {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: threadList),
                vm_size_t(threadsCount) * UInt(MemoryLayout<thread_t>.size)
            )
        }
    }
    
    guard result == KERN_SUCCESS else { return 0.0 }

    var totalUsage: Double = 0.0

    for i in 0..<threadsCount {
        var threadInfo: [integer_t] = Array(repeating: 0, count: Int(THREAD_INFO_MAX))
        var threadInfoCount: mach_msg_type_number_t = mach_msg_type_number_t(THREAD_INFO_MAX)

        let result = threadInfo.withUnsafeMutableBufferPointer { bufferPointer in
            thread_info(
                threadList![Int(i)],
                thread_flavor_t(THREAD_BASIC_INFO),
                bufferPointer.baseAddress,
                &threadInfoCount
            )
        }

        guard result == KERN_SUCCESS else { continue }

        threadInfo.withUnsafeBytes { rawBufferPointer in
            let threadBasicInfo = rawBufferPointer.baseAddress!.assumingMemoryBound(to: thread_basic_info.self).pointee
            if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }
    }

    return totalUsage
}
