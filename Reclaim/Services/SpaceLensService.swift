import Foundation

public final class SpaceLensService: @unchecked Sendable {
    public init() {}
    
    public func scanDirectory(at url: URL, maxDepth: Int = 3, progressHandler: (@Sendable (String) -> Void)? = nil) async throws -> DiskNode {
        return try await traverse(url: url, currentDepth: 0, maxDepth: maxDepth, progressHandler: progressHandler)
    }
    
    private func traverse(url: URL, currentDepth: Int, maxDepth: Int, progressHandler: (@Sendable (String) -> Void)? = nil) async throws -> DiskNode {
        let fm = FileManager.default
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return DiskNode(url: url, name: name, size: 0, isDirectory: false)
        }
        
        if !isDir.boolValue {
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return DiskNode(url: url, name: name, size: Int64(size ?? 0), isDirectory: false)
        }
        
        // If we exceed depth, compute size of folder contents directly and return empty children list to keep it fast
        if currentDepth >= maxDepth {
            let size = calculateDirectorySize(at: url)
            return DiskNode(url: url, name: name, size: size, isDirectory: true, children: [])
        }
        
        progressHandler?(url.lastPathComponent)
        
        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            
            let children = try await withThrowingTaskGroup(of: DiskNode.self) { group in
                for itemURL in contents {
                    group.addTask {
                        try await self.traverse(url: itemURL, currentDepth: currentDepth + 1, maxDepth: maxDepth, progressHandler: progressHandler)
                    }
                }
                
                var nodes: [DiskNode] = []
                for try await node in group {
                    // Only include nodes with non-zero size
                    if node.size > 0 {
                        nodes.append(node)
                    }
                }
                return nodes
            }
            
            let totalSize = children.reduce(0) { $0 + $1.size }
            let sortedChildren = children.sorted(by: { $0.size > $1.size })
            
            return DiskNode(url: url, name: name, size: totalSize, isDirectory: true, children: sortedChildren)
        } catch {
            // Return folder size 0 if it's inaccessible (e.g. System Container directories)
            return DiskNode(url: url, name: name, size: 0, isDirectory: true, children: [])
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
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
    
    private var fm: FileManager {
        FileManager.default
    }
}
