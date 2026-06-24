import Foundation

// MARK: - Task Status
public enum TaskStatus: Sendable, Equatable {
    case idle
    case running(progress: Double)
    case completed(summary: String)
    case failed(error: String)
}

// MARK: - Junk Models
public struct JunkFile: Identifiable, Sendable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public var isChecked: Bool
    
    public init(url: URL, size: Int64, isChecked: Bool = true) {
        self.url = url
        self.size = size
        self.isChecked = isChecked
    }
}

public struct JunkCategory: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let systemIcon: String
    public var size: Int64
    public var isChecked: Bool
    public var files: [JunkFile]
    
    public init(id: String, name: String, systemIcon: String, size: Int64 = 0, isChecked: Bool = true, files: [JunkFile] = []) {
        self.id = id
        self.name = name
        self.systemIcon = systemIcon
        self.size = size
        self.isChecked = isChecked
        self.files = files
    }
}

// MARK: - Uninstaller Models
public struct AppAssociatedFile: Identifiable, Sendable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let size: Int64
    public let typeDescription: String
    public var isChecked: Bool
    
    public init(url: URL, size: Int64, typeDescription: String, isChecked: Bool = true) {
        self.url = url
        self.size = size
        self.typeDescription = typeDescription
        self.isChecked = isChecked
    }
}

public struct InstalledApp: Identifiable, Sendable, Equatable {
    public var id: URL { bundleURL }
    public let name: String
    public let bundleId: String?
    public let bundleURL: URL
    public var appSize: Int64
    public var associatedSize: Int64
    public var isChecked: Bool
    public var associatedFiles: [AppAssociatedFile]
    
    public var totalSize: Int64 {
        return appSize + associatedFiles.filter { $0.isChecked }.reduce(0) { $0 + $1.size }
    }
    
    public init(name: String, bundleId: String?, bundleURL: URL, appSize: Int64 = 0, associatedSize: Int64 = 0, isChecked: Bool = false, associatedFiles: [AppAssociatedFile] = []) {
        self.name = name
        self.bundleId = bundleId
        self.bundleURL = bundleURL
        self.appSize = appSize
        self.associatedSize = associatedSize
        self.isChecked = isChecked
        self.associatedFiles = associatedFiles
    }
}

// MARK: - Space Lens Models
public struct DiskNode: Identifiable, Sendable, Equatable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public var size: Int64
    public let isDirectory: Bool
    public var children: [DiskNode]?
    
    public init(url: URL, name: String, size: Int64, isDirectory: Bool, children: [DiskNode]? = nil) {
        self.url = url
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
    }
}

// MARK: - Maintenance Models
public struct MaintenanceTask: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let details: String
    public let systemIcon: String
    public var status: TaskStatus
    public var isChecked: Bool
    
    public init(id: String, name: String, details: String, systemIcon: String, status: TaskStatus = .idle, isChecked: Bool = true) {
        self.id = id
        self.name = name
        self.details = details
        self.systemIcon = systemIcon
        self.status = status
        self.isChecked = isChecked
    }
}
