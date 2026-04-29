import MyDeskCore
import AppKit
import Quartz
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ResourceListView: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let resources: [ResourcePinModel]
    let knownResources: [ResourcePinModel]
    let scope: WorkbenchScope
    let workspaceId: String?
    let targetFilter: ResourceTargetType?
    let pinImported: Bool
    let onSelect: ((ResourcePinModel) -> Void)?
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onRemove: (ResourcePinModel) -> Void
    @State private var searchText = ""
    @State private var isDropTarget = false
    @State private var renamingResource: ResourcePinModel?

    private var filteredResources: [ResourcePinModel] {
        let typed = resources.filter { resource in
            guard let targetFilter else { return true }
            return resource.targetType == targetFilter
        }
        let ordered = typed.sorted {
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ordered }
        return ordered.filter {
            let cached = $0.searchText.isEmpty ? [
                $0.title,
                $0.originalName,
                $0.customName,
                $0.displayPath,
                $0.note,
                $0.tagsText
            ].joined(separator: " ").lowercased() : $0.searchText
            return cached.contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    addResource()
                } label: {
                    Label("Add Resource", systemImage: "plus")
                }
            }
            TextField("Search resources", text: $searchText)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 0) {
                ResourceListHeader()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredResources) { resource in
                            ResourceRowView(
                                resource: resource,
                                onOpen: { performResourceAction(resource, action: .open) },
                                onReveal: { performResourceAction(resource, action: .reveal) },
                                onCopy: { performResourceAction(resource, action: .copy) },
                                onAlias: { createAlias(for: resource) },
                                onReauthorize: { reauthorize(resource) },
                                onInspect: {
                                    onInspect(.resource(resource.id))
                                    onStatus("Showing info for \(resource.displayName)")
                                },
                                onSelect: {
                                    onSelect?(resource)
                                },
                                onRename: { renamingResource = resource },
                                onTogglePin: { togglePin(resource) },
                                onRemove: { onRemove(resource) }
                            )
                        }
                    }
                }
            }
            .frame(minHeight: 220)
            .background(.background)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isDropTarget ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
                FileDropLoader.loadFileURLs(from: providers) { urls in
                    importDropped(urls)
                }
            }
        }
        .sheet(item: $renamingResource) { resource in
            ResourceRenameSheet(resource: resource) {
                resource.customName = resource.title
                resource.refreshSearchText()
                try? modelContext.save()
                onStatus("Renamed MyDesk metadata: \(resource.displayName)")
            }
        }
    }

    private enum ResourceAction {
        case open
        case reveal
        case copy
    }

    private func addResource() {
        let url: URL?
        switch targetFilter {
        case .folder:
            url = FileDialogs.chooseDirectory(message: "Choose a folder to pin in MyDesk.")
        case .file:
            url = FileDialogs.chooseFile(message: "Choose a file to pin in MyDesk.")
        case nil:
            url = FileDialogs.chooseResource()
        }
        guard let url else { return }
        do {
            let summary = try ResourceImportService().importURLs(
                [url],
                existingResources: knownResources,
                into: modelContext,
                scope: scope,
                workspaceId: workspaceId,
                pinImported: pinImported
            )
            onStatus(summary.statusText)
        } catch {
            onStatus(error.localizedDescription)
        }
    }

    private func importDropped(_ urls: [URL]) {
        let accepted = urls.filter { url in
            guard let targetFilter else { return true }
            return ResourceImportService.targetType(for: url) == targetFilter
        }
        guard !accepted.isEmpty else {
            onStatus("Drop did not include matching files or folders.")
            return
        }
        do {
            let summary = try ResourceImportService().importURLs(
                accepted,
                existingResources: knownResources,
                into: modelContext,
                scope: scope,
                workspaceId: workspaceId,
                pinImported: pinImported
            )
            onStatus(summary.statusText)
        } catch {
            onStatus(error.localizedDescription)
        }
    }

    private func performResourceAction(_ resource: ResourcePinModel, action: ResourceAction) {
        let resolved = BookmarkService().resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
        let url = resolved.url

        do {
            try BookmarkService().access(url) {
                switch action {
                case .open:
                    switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
                    case .open:
                        try FinderService().open(url)
                    case .reveal:
                        try FinderService().reveal(url)
                    }
                    resource.lastOpenedAt = .now
                    resource.status = .available
                    onStatus("Opened \(resource.displayName) in Finder")
                case .reveal:
                    try FinderService().reveal(url)
                    resource.status = .available
                    onStatus("Revealed \(resource.displayName) in Finder")
                case .copy:
                    ClipboardService().copy(url.path)
                    onStatus("Copied path: \(url.path)")
                }
            }
            if resolved.stale {
                resource.status = .staleAuthorization
            }
            resource.lastResolvedPath = url.path
            resource.displayPath = url.path
            resource.refreshSearchText()
            resource.updatedAt = .now
            try modelContext.save()
        } catch {
            resource.status = .unavailable
            try? modelContext.save()
            onStatus(error.localizedDescription)
        }
    }

    private func createAlias(for resource: ResourcePinModel) {
        let resolved = BookmarkService().resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
        guard let requestedAliasURL = FileDialogs.saveAlias(defaultName: "\(resource.effectiveName) alias") else { return }
        let destination = requestedAliasURL.deletingLastPathComponent()
        let name = requestedAliasURL.lastPathComponent
        let bookmarkService = BookmarkService()

        do {
            let aliasURL = try bookmarkService.access(resolved.url) {
                try bookmarkService.access(destination) {
                    try AliasService().createAlias(source: resolved.url, destinationDirectory: destination, name: name)
                }
            }
            let aliasRecord = FinderAliasRecordModel(
                sourceObjectType: "resourcePin",
                sourceObjectId: resource.id,
                aliasDisplayPath: aliasURL.path,
                aliasFileBookmarkData: try? bookmarkService.makeBookmark(for: aliasURL),
                aliasTargetBookmarkData: resource.securityScopedBookmarkData
            )
            modelContext.insert(aliasRecord)
            try modelContext.save()
            onStatus("Created Finder alias: \(aliasURL.path)")
        } catch {
            let failed = FinderAliasRecordModel(sourceObjectType: "resourcePin", sourceObjectId: resource.id, aliasDisplayPath: requestedAliasURL.path, status: .failed)
            modelContext.insert(failed)
            try? modelContext.save()
            onStatus(error.localizedDescription)
        }
    }

    private func reauthorize(_ resource: ResourcePinModel) {
        guard let url = FileDialogs.chooseResource() else { return }
        do {
            resource.securityScopedBookmarkData = try BookmarkService().makeBookmark(for: url)
            resource.displayPath = url.path
            resource.lastResolvedPath = url.path
            resource.originalName = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            resource.status = .available
            resource.updatedAt = .now
            resource.refreshSearchText()
            try modelContext.save()
            onStatus("Reauthorized \(url.path)")
        } catch {
            onStatus(error.localizedDescription)
        }
    }

    private func togglePin(_ resource: ResourcePinModel) {
        resource.isPinned.toggle()
        resource.updatedAt = .now
        resource.refreshSearchText()
        do {
            try modelContext.save()
            onStatus(resource.isPinned ? "Pinned \(resource.displayName)" : "Unpinned \(resource.displayName)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }
}

struct ResourcePreviewView: View {
    @Environment(\.modelContext) private var modelContext
    let resource: ResourcePinModel
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    let onRemove: (ResourcePinModel) -> Void
    @State private var folderItems: [FolderPreviewItem] = []
    @State private var isLoadingFolder = false
    @State private var previewError: String?
    @State private var renamingResource: ResourcePinModel?

    private var resolvedURL: URL {
        BookmarkService().resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath).url
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            resourceHeader
            Divider()

            if resource.targetType == .folder {
                folderPreview
            } else {
                filePreview
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            onInspect(.resource(resource.id))
            if resource.targetType == .folder {
                loadFolderContents()
            }
        }
        .onChange(of: resource.id) { _, _ in
            onInspect(.resource(resource.id))
            if resource.targetType == .folder {
                loadFolderContents()
            }
        }
        .sheet(item: $renamingResource) { resource in
            ResourceRenameSheet(resource: resource) {
                resource.refreshSearchText()
                try? modelContext.save()
                onStatus("Renamed MyDesk metadata: \(resource.displayName)")
            }
        }
    }

    private var resourceHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: resource.targetType == .folder ? "folder.fill" : "doc.fill")
                .font(.system(size: 30))
                .foregroundStyle(resource.targetType == .folder ? Color.accentColor : Color.secondary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(resource.displayName)
                        .font(.title2.bold())
                        .lineLimit(1)
                    if resource.isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(resource.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(resource.note.isEmpty ? "No description yet." : resource.note)
                    .font(.callout)
                    .foregroundStyle(resource.note.isEmpty ? .secondary : .primary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    performResourceAction(.open)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
                Button {
                    performResourceAction(.copy)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
                Button {
                    performResourceAction(.reveal)
                } label: {
                    Label("Reveal", systemImage: "arrow.right.square")
                }
                Button {
                    onInspect(.resource(resource.id))
                    onStatus("Showing info for \(resource.displayName)")
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("Show details")
                Menu {
                    Button("Rename in MyDesk") { renamingResource = resource }
                    Button(resource.isPinned ? "Unpin Shortcut" : "Pin Shortcut") { togglePin() }
                    Divider()
                    Button("Remove from MyDesk", role: .destructive) { onRemove(resource) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More actions")
            }
            .buttonStyle(.bordered)
        }
    }

    private var folderPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Folder Contents")
                    .font(.headline)
                Spacer()
                Button {
                    loadFolderContents()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if isLoadingFolder {
                ProgressView("Loading folder...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let previewError {
                ContentUnavailableView("Folder unavailable", systemImage: "exclamationmark.triangle", description: Text(previewError))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folderItems.isEmpty {
                ContentUnavailableView("Folder is empty", systemImage: "folder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(folderItems) { item in
                    FolderPreviewRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            openPreviewItem(item)
                        }
                        .contextMenu {
                            Button(item.isDirectory ? "Open in Finder" : "Reveal in Finder") {
                                openPreviewItem(item)
                            }
                            Button("Copy Full Path") {
                                ClipboardService().copy(item.path)
                                onStatus("Copied path: \(item.path)")
                            }
                        }
                }
                .listStyle(.inset)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Preview")
                .font(.headline)

            if FileManager.default.fileExists(atPath: resolvedURL.path) {
                QuickLookPreview(url: resolvedURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    }
            } else {
                ContentUnavailableView("File unavailable", systemImage: "exclamationmark.triangle", description: Text(resolvedURL.path))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private enum ResourcePreviewAction {
        case open
        case reveal
        case copy
    }

    private func performResourceAction(_ action: ResourcePreviewAction) {
        let bookmarkService = BookmarkService()
        let resolved = bookmarkService.resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
        do {
            try bookmarkService.access(resolved.url) {
                switch action {
                case .open:
                    switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
                    case .open:
                        try FinderService().open(resolved.url)
                    case .reveal:
                        try FinderService().reveal(resolved.url)
                    }
                    resource.lastOpenedAt = .now
                    onStatus("Opened \(resource.displayName) in Finder")
                case .reveal:
                    try FinderService().reveal(resolved.url)
                    onStatus("Revealed \(resource.displayName) in Finder")
                case .copy:
                    ClipboardService().copy(resolved.url.path)
                    onStatus("Copied path: \(resolved.url.path)")
                }
            }
            resource.lastResolvedPath = resolved.url.path
            resource.displayPath = resolved.url.path
            resource.status = resolved.stale ? .staleAuthorization : .available
            resource.updatedAt = .now
            resource.refreshSearchText()
            try modelContext.save()
        } catch {
            resource.status = .unavailable
            try? modelContext.save()
            onStatus(error.localizedDescription)
        }
    }

    private func loadFolderContents() {
        guard resource.targetType == .folder else { return }
        let bookmarkData = resource.securityScopedBookmarkData
        let fallbackPath = resource.lastResolvedPath
        isLoadingFolder = true
        previewError = nil

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    try FolderPreviewService().contents(bookmarkData: bookmarkData, fallbackPath: fallbackPath)
                }
            }.value

            isLoadingFolder = false
            switch result {
            case .success(let items):
                folderItems = items
            case .failure(let error):
                folderItems = []
                previewError = error.localizedDescription
            }
        }
    }

    private func openPreviewItem(_ item: FolderPreviewItem) {
        do {
            if item.isDirectory {
                try FinderService().open(item.url)
                onStatus("Opened \(item.name) in Finder")
            } else {
                try FinderService().reveal(item.url)
                onStatus("Revealed \(item.name) in Finder")
            }
        } catch {
            onStatus(error.localizedDescription)
        }
    }

    private func togglePin() {
        resource.isPinned.toggle()
        resource.updatedAt = .now
        resource.refreshSearchText()
        do {
            try modelContext.save()
            onStatus(resource.isPinned ? "Pinned \(resource.displayName)" : "Unpinned \(resource.displayName)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }
}

private struct FolderPreviewRow: View {
    let item: FolderPreviewItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDirectory ? "folder" : "doc")
                .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let sizeText {
                Text(sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 3)
    }

    private var sizeText: String? {
        guard !item.isDirectory, let size = item.size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}

private struct ResourceListHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Name")
                .frame(minWidth: 180, maxWidth: 260, alignment: .leading)
            Text("Status")
                .frame(width: 80, alignment: .leading)
            Text("Path")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Actions")
                .frame(width: 238, alignment: .leading)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.28))
    }
}

private struct ResourceRowView: View {
    let resource: ResourcePinModel
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onCopy: () -> Void
    let onAlias: () -> Void
    let onReauthorize: () -> Void
    let onInspect: () -> Void
    let onSelect: () -> Void
    let onRename: () -> Void
    let onTogglePin: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: resource.targetType == .folder ? "folder" : "doc")
                    .foregroundStyle(resource.isPinned ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.displayName)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(resource.targetType == .folder ? "Folder" : "File")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 180, maxWidth: 260, alignment: .leading)

            Text(resource.statusRaw)
                .font(.caption)
                .foregroundStyle(resource.status == .available ? Color.secondary : Color.red)
                .frame(width: 80, alignment: .leading)

            Text(resource.displayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                iconButton("arrow.up.forward.app", "Open", onOpen)
                iconButton("arrow.right.square", "Reveal", onReveal)
                iconButton("doc.on.doc", "Copy full path", onCopy)
                iconButton(resource.isPinned ? "pin.slash" : "pin", resource.isPinned ? "Unpin" : "Pin", onTogglePin)
                iconButton("info.circle", "Details", onInspect)
                Menu {
                    Button("Rename in MyDesk", action: onRename)
                    Button("Create Finder Alias", action: onAlias)
                    Button("Reauthorize", action: onReauthorize)
                    Divider()
                    Button("Remove from MyDesk", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .help("More actions")
            }
            .frame(width: 238, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Open in Finder", action: onOpen)
            Button("Reveal in Finder", action: onReveal)
            Button("Copy Full Path", action: onCopy)
            Button(resource.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Details", action: onInspect)
            Button("Rename in MyDesk", action: onRename)
            Button("Create Finder Alias", action: onAlias)
            Button("Reauthorize", action: onReauthorize)
            Divider()
            Button("Remove from MyDesk", role: .destructive, action: onRemove)
        }
        Divider()
    }

    private func iconButton(_ systemImage: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

enum FileDropLoader {
    static func loadFileURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let group = DispatchGroup()
        let store = DropURLStore()

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsURL = item as? NSURL {
                    url = nsURL as URL
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }

                if let url, url.isFileURL {
                    store.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            completion(store.values)
        }
        return true
    }
}

private final class DropURLStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    var values: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }
}

struct SnippetLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    let snippets: [SnippetModel]
    let resources: [ResourcePinModel]
    let scope: WorkbenchScope?
    let workspaceId: String?
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var pendingRun: CommandRunRequest?

    private var filteredSnippets: [SnippetModel] {
        let scoped = snippets.filter { snippet in
            guard let scope else { return true }
            switch scope {
            case .global:
                return snippet.scope == .global
            case .workspace:
                return snippet.scope == .global || snippet.workspaceId == workspaceId
            }
        }
        guard !searchText.isEmpty else { return scoped }
        return scoped.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText) ||
            $0.details.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Snippets")
                    .font(.headline)
                Spacer()
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                }
            }
            TextField("Search snippets", text: $searchText)
                .textFieldStyle(.roundedBorder)
            Table(filteredSnippets) {
                TableColumn("Title") { snippet in
                    Label(snippet.title, systemImage: snippet.kind == .prompt ? "text.quote" : "terminal")
                }
                TableColumn("Kind") { snippet in
                    Text(snippet.kind.rawValue.capitalized)
                }
                TableColumn("Body") { snippet in
                    Text(snippet.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                TableColumn("Actions") { snippet in
                    HStack {
                        Button("Copy") { copy(snippet) }
                        if snippet.kind == .command {
                            Button("Terminal") { openTerminal(snippet) }
                            Button("Run") { prepareRun(snippet) }
                        }
                        Button {
                            onInspect(.snippet(snippet.id))
                        } label: {
                            Image(systemName: "info.circle")
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .frame(minHeight: 220)
        }
        .sheet(isPresented: $showingEditor) {
            SnippetEditor(scope: scope ?? .global, workspaceId: workspaceId) { snippet in
                modelContext.insert(snippet)
                try? modelContext.save()
                onStatus("Created snippet: \(snippet.title)")
            }
        }
        .alert("Run command in Terminal?", isPresented: Binding(
            get: { pendingRun != nil },
            set: { if !$0 { pendingRun = nil } }
        )) {
            Button("Run", role: .destructive) {
                if let pendingRun {
                    run(pendingRun)
                }
                pendingRun = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRun = nil
            }
        } message: {
            if let pendingRun {
                Text("\(pendingRun.snippet.body)\n\nWorking directory: \(pendingRun.workingDirectory)")
            }
        }
    }

    private func copy(_ snippet: SnippetModel) {
        ClipboardService().copy(snippet.body)
        snippet.lastCopiedAt = .now
        snippet.updatedAt = .now
        try? modelContext.save()
        onStatus("Copied \(snippet.kind.rawValue): \(snippet.title)")
    }

    private func openTerminal(_ snippet: SnippetModel) {
        do {
            let directory = try resolvedWorkingDirectory(for: snippet)
            try TerminalService().open(at: directory)
            snippet.lastUsedAt = .now
            try? modelContext.save()
            onStatus("Opened Terminal at \(directory)")
        } catch {
            ClipboardService().copy(snippet.body)
            onStatus("Terminal automation failed; copied command instead. \(error.localizedDescription)")
        }
    }

    private func prepareRun(_ snippet: SnippetModel) {
        do {
            pendingRun = CommandRunRequest(snippet: snippet, workingDirectory: try resolvedWorkingDirectory(for: snippet))
        } catch {
            ClipboardService().copy(snippet.body)
            onStatus("Could not resolve working directory; copied command. \(error.localizedDescription)")
        }
    }

    private func run(_ request: CommandRunRequest) {
        let snippet = request.snippet
        do {
            try TerminalService().run(command: snippet.body, workingDirectory: request.workingDirectory)
            snippet.lastUsedAt = .now
            try? modelContext.save()
            onStatus("Requested Terminal run: \(snippet.title)")
        } catch {
            let runError = error
            ClipboardService().copy(snippet.body)
            do {
                try TerminalService().open(at: request.workingDirectory)
                onStatus("Terminal run failed; copied command and opened Terminal at \(request.workingDirectory). \(runError.localizedDescription)")
            } catch {
                onStatus("Terminal run failed; copied command. Could not open Terminal at \(request.workingDirectory): \(error.localizedDescription)")
            }
        }
    }

    private func resolvedWorkingDirectory(for snippet: SnippetModel) throws -> String {
        guard let ref = snippet.workingDirectoryRef,
              let resource = resources.first(where: { $0.id == ref }) else {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }

        let bookmarkService = BookmarkService()
        let resolved = bookmarkService.resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
        var isDirectory: ObjCBool = false
        try bookmarkService.access(resolved.url) {
            guard FileManager.default.fileExists(atPath: resolved.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw WorkbenchError.missingPath(resolved.url.path)
            }
        }

        resource.lastResolvedPath = resolved.url.path
        resource.displayPath = resolved.url.path
        resource.status = resolved.stale ? .staleAuthorization : .available
        resource.updatedAt = .now
        try modelContext.save()
        return resolved.url.path
    }
}

private struct CommandRunRequest {
    let snippet: SnippetModel
    let workingDirectory: String
}

struct SnippetEditor: View {
    @Environment(\.dismiss) private var dismiss
    let scope: WorkbenchScope
    let workspaceId: String?
    let onSave: (SnippetModel) -> Void

    @State private var title = ""
    @State private var kind: SnippetKind = .prompt
    @State private var snippetBody = ""
    @State private var details = ""
    @State private var tags = ""
    @State private var requiresConfirmation = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Snippet")
                .font(.title2.bold())
            TextField("Title", text: $title)
            Picker("Kind", selection: $kind) {
                ForEach(SnippetKind.allCases) { kind in
                    Text(kind.rawValue.capitalized).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            TextField("Tags", text: $tags)
            TextField("Description", text: $details, axis: .vertical)
            TextEditor(text: $snippetBody)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            Toggle("Require confirmation before running command", isOn: $requiresConfirmation)
                .disabled(kind == .prompt)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let snippet = SnippetModel(
                        workspaceId: scope == .workspace ? workspaceId : nil,
                        title: title.isEmpty ? "Untitled Snippet" : title,
                        kind: kind,
                        body: snippetBody,
                        details: details,
                        tags: tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) },
                        scope: scope,
                        requiresConfirmation: kind == .command ? requiresConfirmation : false
                    )
                    onSave(snippet)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560, height: 520)
    }
}
