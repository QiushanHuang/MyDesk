import Foundation
import MyDeskCore
import SwiftData

enum PersistentStoreBootstrap {
    static func makeModelContainer(fileManager: FileManager = .default) throws -> ModelContainer {
        let layout = try makeLayout(fileManager: fileManager)
        try prepareStore(at: layout, fileManager: fileManager)

        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(schema: schema, url: layout.storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static var modelTypes: [any PersistentModel.Type] {
        [
            WorkspaceModel.self,
            ResourcePinModel.self,
            SnippetModel.self,
            CanvasModel.self,
            CanvasNodeModel.self,
            CanvasEdgeModel.self,
            FinderAliasRecordModel.self
        ]
    }

    private static func makeLayout(fileManager: FileManager) throws -> MyDeskStoreLayout {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return MyDeskStoreLayout(applicationSupportDirectory: support)
    }

    private static func prepareStore(at layout: MyDeskStoreLayout, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: layout.storeDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.backupDirectory, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: layout.storeURL.path),
           fileManager.fileExists(atPath: layout.legacyDefaultStoreURL.path) {
            try copySQLiteFileSet(from: layout.legacyDefaultStoreURL, to: layout.storeURL, fileManager: fileManager)
        }

        try backupSQLiteFileSetIfPresent(layout: layout, fileManager: fileManager)
        try pruneOldBackups(layout: layout, fileManager: fileManager)
    }

    private static func copySQLiteFileSet(from sourceStore: URL, to destinationStore: URL, fileManager: FileManager) throws {
        let sources = MyDeskStoreLayout.sqliteFileSet(for: sourceStore)
        let destinations = MyDeskStoreLayout.sqliteFileSet(for: destinationStore)
        for (source, destination) in zip(sources, destinations) where fileManager.fileExists(atPath: source.path) {
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private static func backupSQLiteFileSetIfPresent(layout: MyDeskStoreLayout, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: layout.storeURL.path) else { return }

        let folderName = MyDeskStoreLayout.backupFolderName(for: .now)
        var backupFolder = layout.backupDirectory.appendingPathComponent(folderName, isDirectory: true)
        if fileManager.fileExists(atPath: backupFolder.path) {
            backupFolder = layout.backupDirectory.appendingPathComponent("\(folderName)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        }
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        for source in MyDeskStoreLayout.sqliteFileSet(for: layout.storeURL) where fileManager.fileExists(atPath: source.path) {
            let destination = backupFolder.appendingPathComponent(source.lastPathComponent, isDirectory: false)
            try fileManager.copyItem(at: source, to: destination)
        }
    }

    private static func pruneOldBackups(layout: MyDeskStoreLayout, fileManager: FileManager) throws {
        let folders = try fileManager.contentsOfDirectory(
            at: layout.backupDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for folder in MyDeskStoreLayout.backupFoldersToPrune(folders, keepingNewest: MyDeskStoreLayout.backupRetentionCount) {
            try fileManager.removeItem(at: folder)
        }
    }
}
