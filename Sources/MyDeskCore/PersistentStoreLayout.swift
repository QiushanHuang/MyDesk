import Foundation

public struct MyDeskStoreLayout: Equatable, Sendable {
    public static let bundleIdentifier = "studio.qiushan.mydesk"
    public static let storeFileName = "MyDesk.store"
    public static let backupRetentionCount = 20

    public let applicationSupportDirectory: URL

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
    }

    public var appDirectory: URL {
        applicationSupportDirectory.appendingPathComponent(Self.bundleIdentifier, isDirectory: true)
    }

    public var storeDirectory: URL {
        appDirectory.appendingPathComponent("Stores", isDirectory: true)
    }

    public var storeURL: URL {
        storeDirectory.appendingPathComponent(Self.storeFileName, isDirectory: false)
    }

    public var backupDirectory: URL {
        appDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    public var legacyDefaultStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("default.store", isDirectory: false)
    }

    public static func sqliteFileSet(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
    }

    public static func backupFolderName(for date: Date, timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    public static func backupFoldersToPrune(_ folders: [URL], keepingNewest count: Int) -> [URL] {
        guard count >= 0 else { return [] }
        let timestampedFolders = folders.filter { isTimestampedBackupFolder($0.lastPathComponent) }
        let newestFirst = timestampedFolders.sorted { $0.lastPathComponent > $1.lastPathComponent }
        return Array(newestFirst.dropFirst(count)).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func isTimestampedBackupFolder(_ name: String) -> Bool {
        guard name.count == 15 else { return false }
        let dashIndex = name.index(name.startIndex, offsetBy: 8)
        guard name[dashIndex] == "-" else { return false }
        return name.enumerated().allSatisfy { index, character in
            index == 8 || character.isNumber
        }
    }
}
