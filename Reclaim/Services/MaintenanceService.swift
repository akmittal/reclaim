import Foundation

public final class MaintenanceService: @unchecked Sendable {
    public init() {}
    
    public func executeTask(id: String, progressHandler: (@Sendable (Double) -> Void)?) async throws -> String {
        switch id {
        case "ram":
            progressHandler?(0.2)
            try await runCommand(path: "/usr/sbin/purge", arguments: [])
            progressHandler?(1.0)
            return "Purged inactive memory and released caches."
        case "dns":
            progressHandler?(0.3)
            try await runCommand(path: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
            progressHandler?(0.7)
            // Note: killall HUP mDNSResponder might fail depending on session type, we execute but handle failure gracefully
            _ = try? await runCommand(path: "/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
            progressHandler?(1.0)
            return "Successfully flushed local DNS resolver cache."
        case "spotlight":
            progressHandler?(0.3)
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            progressHandler?(0.6)
            // Reindexing the user's home directory works without root privileges
            try await runCommand(path: "/usr/bin/mdutil", arguments: ["-E", homePath])
            progressHandler?(1.0)
            return "Rebuilt Spotlight database index for: \(homePath)"
        default:
            throw NSError(domain: "MaintenanceService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
    }
    
    private func runCommand(path: String, arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        
        // Use a task to wait for the command without blocking the thread pool
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
        
        if process.terminationStatus != 0 {
            let errorData = try? pipe.fileHandleForReading.readToEnd()
            let errorText = errorData.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw NSError(
                domain: "MaintenanceService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Process exited with code \(process.terminationStatus). \(errorText)"]
            )
        }
    }
}
