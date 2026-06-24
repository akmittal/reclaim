import Foundation

public final class JunkCleanerService: @unchecked Sendable {
    public init() {}
    
    private func logToFile(_ message: String) {
        let debugLogURL = URL(fileURLWithPath: "/Users/akmittal/projects/reclaim/app_debug.log")
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let formattedMessage = "[\(timestamp)] \(message)\n"
        if let fileHandle = try? FileHandle(forWritingTo: debugLogURL) {
            fileHandle.seekToEndOfFile()
            if let data = formattedMessage.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? formattedMessage.write(to: debugLogURL, atomically: true, encoding: .utf8)
        }
    }

    public func scanAllCategories(progressHandler: (@Sendable (String) -> Void)?) async throws -> [JunkCategory] {
        logToFile("--- Starting scanAllCategories ---")
        let categories = [
            (id: "user_caches", name: "User Caches", root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")),
            (id: "user_logs", name: "User Logs", root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")),
            (id: "system_caches", name: "System Caches", root: URL(fileURLWithPath: "/Library/Caches")),
            (id: "system_logs", name: "System Logs", root: URL(fileURLWithPath: "/Library/Logs")),
            (id: "xcode", name: "Xcode Developer Junk", root: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/DerivedData")),
            (id: "trash", name: "Trash Bins", root: FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
        ]
        
        var resultCategories: [JunkCategory] = []
        
        for cat in categories {
            progressHandler?(cat.name)
            logToFile("Scanning category: \(cat.name) at \(cat.root.path)")
            let files = await scanRootDirectory(cat.root, progressHandler: progressHandler)
            let totalSize = files.reduce(0) { $0 + $1.size }
            logToFile("Category \(cat.name) scan finished. Found \(files.count) files, total size: \(totalSize) bytes")
            let icon: String
            switch cat.id {
            case "user_caches": icon = "folder.badge.gearshape"
            case "user_logs": icon = "doc.text"
            case "system_caches": icon = "folder.fill.badge.gearshape"
            case "system_logs": icon = "doc.text.fill"
            case "xcode": icon = "hammer.fill"
            default: icon = "trash"
            }
            resultCategories.append(JunkCategory(id: cat.id, name: cat.name, systemIcon: icon, size: totalSize, isChecked: true, files: files))
        }
        
        logToFile("--- scanAllCategories Completed ---")
        return resultCategories
    }
    
    private func scanRootDirectory(_ root: URL, progressHandler: (@Sendable (String) -> Void)?) async -> [JunkFile] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else {
            logToFile("Directory does not exist: \(root.path)")
            return []
        }
        
        let localHandler = progressHandler ?? { _ in }
        let isTrash = root.path.hasSuffix("/.Trash")
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            logToFile("POSIX contentsOfDirectory returned \(contents.count) items for \(root.path)")
            
            return await withTaskGroup(of: JunkFile?.self) { group in
                for itemURL in contents {
                    group.addTask {
                        let localFM = FileManager.default
                        let pathString = itemURL.lastPathComponent
                        localHandler(pathString)
                        
                        // Only proceed if the file/folder is writable by the current user process
                        let isHomeDir = itemURL.path.hasPrefix(NSHomeDirectory())
                        if !isHomeDir {
                            guard localFM.isWritableFile(atPath: itemURL.path) else {
                                return nil
                            }
                        }
                        
                        var isDir: ObjCBool = false
                        if localFM.fileExists(atPath: itemURL.path, isDirectory: &isDir) {
                            let size: Int64
                            if isDir.boolValue {
                                size = self.calculateDirectorySize(at: itemURL)
                            } else {
                                size = self.calculateFileSize(at: itemURL)
                            }
                            if size > 0 {
                                return JunkFile(url: itemURL, size: size)
                            }
                        }
                        return nil
                    }
                }
                
                var files: [JunkFile] = []
                for await case let junkFile? in group {
                    files.append(junkFile)
                }
                // Sort by size descending
                return files.sorted(by: { $0.size > $1.size })
            }
        } catch {
            logToFile("POSIX scan error for \(root.path): \(error.localizedDescription)")
            if isTrash {
                logToFile("Attempting AppleScript fallback for Trash Bins...")
                let appleScriptFiles = await scanTrashViaAppleScript()
                logToFile("AppleScript fallback found \(appleScriptFiles.count) items in Trash.")
                if !appleScriptFiles.isEmpty {
                    return appleScriptFiles.sorted(by: { $0.size > $1.size })
                }
            }
            return []
        }
    }
    
    @MainActor
    private func scanTrashViaAppleScript() -> [JunkFile] {
        let scriptSource = """
        tell application "Finder"
            set out to ""
            repeat with i in (get every item of trash)
                try
                    set out to out & (name of i) & "::" & (size of i) & "\n"
                end try
            end repeat
            return out
        end tell
        """
        guard let appleScript = NSAppleScript(source: scriptSource) else {
            logToFile("Failed to initialize NSAppleScript")
            return []
        }
        var errorInfo: NSDictionary?
        let resultEvent = appleScript.executeAndReturnError(&errorInfo)
        if let errorInfo = errorInfo {
            logToFile("NSAppleScript execution error: \(errorInfo)")
            return []
        }
        guard let output = resultEvent.stringValue else {
            logToFile("NSAppleScript result.stringValue is nil")
            return []
        }
        
        let fileManager = FileManager.default
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        
        var files: [JunkFile] = []
        let lines = output.split(separator: "\n")
        logToFile("AppleScript returned output string lines count: \(lines.count)")
        for line in lines {
            let parts = line.components(separatedBy: "::")
            if parts.count == 2 {
                let name = parts[0]
                let sizeString = parts[1]
                if let size = Int64(sizeString) {
                    let fileURL = trashURL.appendingPathComponent(name)
                    files.append(JunkFile(url: fileURL, size: size))
                } else {
                    logToFile("Failed to parse size from line: \(line)")
                }
            } else {
                logToFile("Invalid format line returned by AppleScript: \(line)")
            }
        }
        return files
    }
    
    private func calculateFileSize(at url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return 0
        }
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    size += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                // Ignore inaccessible file
            }
        }
        return size
    }
    
    public func deleteFiles(_ urls: [URL]) async -> (deletedBytes: Int64, errors: [String]) {
        let fileManager = FileManager.default
        var deletedBytes: Int64 = 0
        var errors: [String] = []
        var shouldEmptyTrash = false
        
        logToFile("Starting deleteFiles for \(urls.count) URLs")
        
        for url in urls {
            let isTrashItem = url.path.contains("/.Trash/") || url.path.hasSuffix("/.Trash")
            if isTrashItem {
                shouldEmptyTrash = true
                continue
            }
            
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                let size = isDir.boolValue ? calculateDirectorySize(at: url) : calculateFileSize(at: url)
                do {
                    // Safety check to ensure we do not delete system directories or root paths
                    let protectedPaths = ["/", "/System", "/Library", "/Users", "/Users/Shared"]
                    if protectedPaths.contains(url.path) || url.path.split(separator: "/").count < 3 {
                        errors.append("Skipped protected path: \(url.path)")
                        continue // Skip dangerous deletions
                    }
                    try fileManager.removeItem(at: url)
                    deletedBytes += size
                } catch {
                    errors.append("Failed to delete \(url.path): \(error.localizedDescription)")
                }
            } else {
                errors.append("File does not exist at path: \(url.path)")
            }
        }
        
        if shouldEmptyTrash {
            logToFile("Triggering AppleScript empty trash...")
            let trashReclaimed = await emptyTrashViaAppleScript()
            deletedBytes += trashReclaimed
            logToFile("AppleScript empty trash reclaimed \(trashReclaimed) bytes")
        }
        
        return (deletedBytes, errors)
    }
    
    @MainActor
    private func emptyTrashViaAppleScript() -> Int64 {
        let scriptSource = """
        tell application "Finder"
            set totalSize to 0
            repeat with i in (get every item of trash)
                try
                    set totalSize to totalSize + (size of i)
                end try
            end repeat
            try
                empty trash without warnings
            end try
            return totalSize
        end tell
        """
        guard let appleScript = NSAppleScript(source: scriptSource) else {
            logToFile("Failed to initialize emptyTrash NSAppleScript")
            return 0
        }
        var errorInfo: NSDictionary?
        let resultEvent = appleScript.executeAndReturnError(&errorInfo)
        if let errorInfo = errorInfo {
            logToFile("NSAppleScript emptyTrash execution error: \(errorInfo)")
            return 0
        }
        guard let output = resultEvent.stringValue else {
            logToFile("NSAppleScript emptyTrash result stringValue is nil")
            return 0
        }
        
        return Int64(output) ?? 0
    }
}
