import MyDeskCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private enum CanvasInteractionMode: String, CaseIterable, Identifiable {
    case select
    case connect
    case boxSelect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Select"
        case .connect: "Connect"
        case .boxSelect: "Box Select"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .connect: "point.3.connected.trianglepath.dotted"
        case .boxSelect: "selection.pin.in.out"
        }
    }
}

private struct CanvasEdgeSegment: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
}

enum CanvasGlowTheme: String, CaseIterable, Identifiable {
    case blue
    case minimal
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "Blue"
        case .minimal: "Minimal"
        case .off: "Off"
        }
    }
}

private enum CanvasNodeMetrics {
    static let cardWidth = 214.0
    static let cardHeight = 132.0
    static let noteHeight = 146.0
    static let frameWidth = 360.0
    static let frameHeight = 250.0
    static let frameMinWidth = 240.0
    static let frameMinHeight = 160.0
    static let edgeTargetClearance = 0.0
    static let zoomBaseline = 0.35
    static let zoomMinimum = 0.12
    static let zoomMaximum = 2.4
    static let zoomDisplayStep = 0.1
}

private struct CanvasRenderSnapshot {
    let workflowNodes: [CanvasNodeModel]
    let nodeById: [String: CanvasNodeModel]
    let resourcesById: [String: ResourcePinModel]
    let snippetsById: [String: SnippetModel]
    let visibleEdges: [CanvasEdgeModel]
    let frameNodes: [CanvasNodeModel]
    let cardNodes: [CanvasNodeModel]
    let connectedNodeIDs: Set<String>

    init(nodes: [CanvasNodeModel], resources: [ResourcePinModel], snippets: [SnippetModel], edges: [CanvasEdgeModel]) {
        let nodeLookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        workflowNodes = nodes
        nodeById = nodeLookup
        resourcesById = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        snippetsById = Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0) })
        visibleEdges = edges.filter { nodeLookup[$0.sourceNodeId] != nil && nodeLookup[$0.targetNodeId] != nil }
        frameNodes = nodes.filter { $0.nodeType == .groupFrame }.sorted { $0.updatedAt < $1.updatedAt }
        cardNodes = nodes.filter { $0.nodeType != .groupFrame }.sorted { $0.zIndex < $1.zIndex }
        connectedNodeIDs = Set(visibleEdges.flatMap { [$0.sourceNodeId, $0.targetNodeId] })
    }

    func resource(for node: CanvasNodeModel) -> ResourcePinModel? {
        guard node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    func snippet(for node: CanvasNodeModel) -> SnippetModel? {
        guard node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    func edgeSegments(
        targetClearance: Double,
        rectFor: (CanvasNodeModel) -> CanvasFrameRect
    ) -> [CanvasEdgeSegment] {
        visibleEdges.compactMap { edge in
            guard let source = nodeById[edge.sourceNodeId],
                  let target = nodeById[edge.targetNodeId] else {
                return nil
            }
            let anchors = CanvasEdgeAnchoring.anchors(source: rectFor(source), target: rectFor(target), targetClearance: targetClearance)
            return CanvasEdgeSegment(
                id: edge.id,
                start: CGPoint(x: anchors.start.x, y: anchors.start.y),
                end: CGPoint(x: anchors.end.x, y: anchors.end.y)
            )
        }
    }
}

struct WorkspaceCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let canvas: CanvasModel
    let resources: [ResourcePinModel]
    let snippets: [SnippetModel]
    let nodes: [CanvasNodeModel]
    let edges: [CanvasEdgeModel]
    let onStatus: (String) -> Void
    let onInspect: (InspectorSelection) -> Void

    @State private var selectedNodeIDs: Set<String> = []
    @State private var mode: CanvasInteractionMode = .select
    @State private var connectionSourceNodeId: String?
    @State private var selectionRect: CGRect?
    @State private var nodeDragStart: [String: CGPoint] = [:]
    @State private var transientNodeOffsets: [String: CGSize] = [:]
    @State private var transientViewportOffset: CGSize = .zero
    @State private var zoomStart: Double?
    @State private var transientZoom: Double?
    @State private var isDropTarget = false
    @State private var suppressedTapNodeId: String?
    @State private var frameResizeStartSizes: [String: CGSize] = [:]
    @State private var transientFrameSizes: [String: CGSize] = [:]
    @State private var resizingFrameNodeId: String?
    @State private var isCanvasInspectorVisible = false

    private var zoom: CGFloat {
        CGFloat(effectiveZoom)
    }

    private var effectiveZoom: Double {
        CanvasZoomScale.clamped(transientZoom ?? canvas.zoom, minimum: CanvasNodeMetrics.zoomMinimum, maximum: CanvasNodeMetrics.zoomMaximum)
    }

    private var effectiveViewportX: Double {
        canvas.viewportX + Double(transientViewportOffset.width)
    }

    private var effectiveViewportY: Double {
        canvas.viewportY + Double(transientViewportOffset.height)
    }

    private var workflowNodes: [CanvasNodeModel] {
        nodes
    }

    private var workflowNodeById: [String: CanvasNodeModel] {
        Dictionary(uniqueKeysWithValues: workflowNodes.map { ($0.id, $0) })
    }

    private var resourcesById: [String: ResourcePinModel] {
        Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
    }

    private var snippetsById: [String: SnippetModel] {
        Dictionary(uniqueKeysWithValues: snippets.map { ($0.id, $0) })
    }

    private var visibleEdges: [CanvasEdgeModel] {
        edges.filter { workflowNodeById[$0.sourceNodeId] != nil && workflowNodeById[$0.targetNodeId] != nil }
    }

    private var glowTheme: CanvasGlowTheme {
        CanvasGlowTheme(rawValue: canvas.linkAnimationThemeRaw) ?? .blue
    }

    private var shouldAnimateGlow: Bool {
        CanvasEdgeAnimationPolicy.shouldAnimateEdge(
            theme: canvas.linkAnimationThemeRaw,
            animationsEnabled: canvas.animationsEnabled,
            reduceMotion: reduceMotion,
            edgeCount: visibleEdges.count
        )
    }

    private var renderSnapshot: CanvasRenderSnapshot {
        CanvasRenderSnapshot(nodes: workflowNodes, resources: resources, snippets: snippets, edges: edges)
    }

    var body: some View {
        HStack(spacing: 12) {
            canvasLeftRail
                .frame(width: 196)
            canvasSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if isCanvasInspectorVisible {
                canvasRightRail
                    .frame(width: 244)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.16), value: isCanvasInspectorVisible)
    }

    private var canvasLeftRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Canvas")
                        .font(.headline)
                    Text("Place resources and connect the workflow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button {
                    isCanvasInspectorVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .tint(isCanvasInspectorVisible ? .accentColor : nil)
                .help(isCanvasInspectorVisible ? "Hide canvas inspector" : "Show canvas inspector")
            }

            GroupBox("Add") {
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        ForEach(resources) { resource in
                            Button(resource.title) { addResourceNode(resource) }
                        }
                    } label: {
                        Label("Resource", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(resources.isEmpty)

                    Menu {
                        ForEach(snippets) { snippet in
                            Button(snippet.title) { addSnippetNode(snippet) }
                        }
                    } label: {
                        Label("Prompt / Command", systemImage: "text.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(snippets.isEmpty)

                    Button {
                        addNoteNode()
                    } label: {
                        Label("Note", systemImage: "note.text.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        addFrameNode()
                    } label: {
                        Label("Organization Frame", systemImage: "rectangle.dashed")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.bordered)
            }

            GroupBox("Mode") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(CanvasInteractionMode.allCases) { item in
                        Button {
                            mode = item
                            selectionRect = nil
                            connectionSourceNodeId = nil
                        } label: {
                            Label(item.title, systemImage: item.systemImage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(mode == item ? .accentColor : nil)
                    }
                }
            }

            GroupBox("Zoom") {
                HStack {
                    Button {
                        setZoom(effectiveZoom - CanvasNodeMetrics.zoomBaseline * CanvasNodeMetrics.zoomDisplayStep)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    Button {
                        setZoom(CanvasNodeMetrics.zoomBaseline)
                    } label: {
                        Text("\(CanvasZoomScale.displayPercent(forZoom: effectiveZoom, baseline: CanvasNodeMetrics.zoomBaseline))%")
                            .monospacedDigit()
                    }
                    .help("Reset canvas scale to 100%")
                    Button {
                        setZoom(effectiveZoom + CanvasNodeMetrics.zoomBaseline * CanvasNodeMetrics.zoomDisplayStep)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
                .buttonStyle(.bordered)
            }

            GroupBox("Glow") {
                Picker("Glow", selection: Binding(
                    get: { glowTheme },
                    set: { theme in
                        canvas.linkAnimationThemeRaw = theme.rawValue
                        canvas.animationsEnabled = theme != .off
                        canvas.updatedAt = .now
                        try? modelContext.save()
                    }
                )) {
                    ForEach(CanvasGlowTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canvasRightRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Selection") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button { openSelectedNode() } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedResource == nil)

                    Button { copySelectedNode() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedNode == nil)

                    Button { createAliasForSelectedNode() } label: {
                        Label("Alias", systemImage: "arrowshape.turn.up.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedResource == nil)

                    Button(role: .destructive) { deleteSelectedNodes() } label: {
                        Label("Delete Card", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedNodeIDs.isEmpty)
                }
                .buttonStyle(.bordered)
            }

            GroupBox("Connections") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(connectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button { connectSelected() } label: {
                        Label("Connect Selected", systemImage: "link")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedNodeIDs.count != 2)

                    Button(role: .destructive) { deleteSelectedConnections() } label: {
                        Label("Delete Links", systemImage: "link.badge.minus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedNodeIDs.isEmpty)
                }
                .buttonStyle(.bordered)
            }

            GroupBox("Layout") {
                VStack(alignment: .leading, spacing: 8) {
                    Button { alignLeft() } label: {
                        Label("Align Left", systemImage: "align.horizontal.left")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedNodeIDs.count < 2)

                    Button { alignTop() } label: {
                        Label("Align Top", systemImage: "align.vertical.top")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedNodeIDs.count < 2)

                    Button { autoArrange() } label: {
                        Label("Auto Arrange", systemImage: "square.grid.3x3")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canvasSurface: some View {
        GeometryReader { proxy in
            let snapshot = renderSnapshot
            let edgeSegments = snapshot.edgeSegments(targetClearance: CanvasNodeMetrics.edgeTargetClearance, rectFor: screenRect(for:))
            ZStack(alignment: .topLeading) {
                canvasBackground

                ForEach(snapshot.frameNodes) { node in
                    CanvasFrameCard(
                        node: node,
                        isSelected: selectedNodeIDs.contains(node.id),
                        isConnected: false,
                        glowTheme: glowTheme,
                        animateGlow: false,
                        glowPulse: false,
                        isConnectionSource: connectionSourceNodeId == node.id,
                        onInfo: { performCardButtonAction(node) { inspect(node) } },
                        onCopy: { performCardButtonAction(node) { copyNodePayload(node) } },
                        onConnect: { performCardButtonAction(node) { connectButtonTapped(node) } },
                        onDelete: { performCardButtonAction(node) { delete(node) } },
                        onResizeChanged: { resizeFrame(node, screenTranslation: $0, commit: false) },
                        onResizeEnded: { resizeFrame(node, screenTranslation: $0, commit: true) }
                    )
                    .frame(width: nodeSize(for: node).width * Double(zoom), height: nodeSize(for: node).height * Double(zoom))
                    .position(screenPoint(for: node))
                    .gesture(dragGesture(for: node))
                    .simultaneousGesture(TapGesture(count: 1).onEnded {
                        handleNodeTap(node)
                    })
                    .zIndex(0)
                }

                ForEach(edgeSegments) { segment in
                    FlowingArrowEdge(
                        start: segment.start,
                        end: segment.end,
                        theme: glowTheme,
                        isAnimated: shouldAnimateGlow,
                        canvasSize: proxy.size
                    )
                    .zIndex(1.2)
                }

                ForEach(snapshot.cardNodes) { node in
                    CanvasNodeCard(
                        node: node,
                        resource: snapshot.resource(for: node),
                        snippet: snapshot.snippet(for: node),
                        isSelected: selectedNodeIDs.contains(node.id),
                        isConnectionSource: connectionSourceNodeId == node.id,
                        isConnected: false,
                        glowTheme: glowTheme,
                        animateGlow: false,
                        glowPulse: false,
                        onOpen: { open(node) },
                        onInfo: { performCardButtonAction(node) { inspect(node) } },
                        onCopy: { performCardButtonAction(node) { copyNodePayload(node) } },
                        onConnect: { performCardButtonAction(node) { connectButtonTapped(node) } },
                        onToggleNote: { performCardButtonAction(node) { toggleNote(for: node) } },
                        onDelete: { performCardButtonAction(node) { delete(node) } }
                    )
                    .frame(width: nodeSize(for: node).width * Double(zoom), height: nodeSize(for: node).height * Double(zoom))
                    .position(screenPoint(for: node))
                    .gesture(dragGesture(for: node))
                    .onTapGesture(count: 2) {
                        open(node)
                    }
                    .simultaneousGesture(TapGesture(count: 1).onEnded {
                        handleNodeTap(node)
                    })
                    .zIndex(2)
                }

                ForEach(edgeSegments) { segment in
                    FlowingArrowHead(
                        start: segment.start,
                        end: segment.end,
                        theme: glowTheme,
                        isAnimated: shouldAnimateGlow,
                        canvasSize: proxy.size
                    )
                    .zIndex(2.7)
                }

                if let selectionRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay {
                            Rectangle()
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                        .zIndex(3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDropTarget ? Color.accentColor : .clear, lineWidth: 2)
            }
            .gesture(backgroundDrag(in: proxy.size))
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                let start = zoomStart ?? canvas.zoom
                if zoomStart == nil {
                    zoomStart = start
                }
                transientZoom = CanvasZoomScale.clamped(
                    start * Double(value.magnification),
                    minimum: CanvasNodeMetrics.zoomMinimum,
                    maximum: CanvasNodeMetrics.zoomMaximum
                )
            }.onEnded { _ in
                if let transientZoom {
                    canvas.zoom = transientZoom
                    canvas.updatedAt = .now
                    try? modelContext.save()
                }
                zoomStart = nil
                transientZoom = nil
            })
            .onDrop(
                of: [UTType.fileURL],
                delegate: CanvasFileDropDelegate(isTargeted: $isDropTarget) { providers, location in
                    _ = FileDropLoader.loadFileURLs(from: providers) { urls in
                        importDroppedResources(urls, at: location)
                    }
                }
            )
        }
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var canvasBackground: some View {
        Rectangle()
            .fill(.background)
            .overlay {
                GridPattern()
                    .stroke(.quaternary, lineWidth: 0.5)
            }
            .zIndex(-10)
    }

    private func screenPoint(for node: CanvasNodeModel) -> CGPoint {
        let offset = transientNodeOffsets[node.id] ?? .zero
        let size = nodeSize(for: node)
        let point = CanvasViewportProjection.screenPoint(
            id: node.id,
            x: node.x,
            y: node.y,
            width: size.width,
            height: size.height,
            offsetX: Double(offset.width),
            offsetY: Double(offset.height),
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
        return CGPoint(
            x: point.x,
            y: point.y
        )
    }

    private func screenRect(for node: CanvasNodeModel) -> CanvasFrameRect {
        let offset = transientNodeOffsets[node.id] ?? .zero
        let size = nodeSize(for: node)
        return CanvasViewportProjection.screenRect(
            id: node.id,
            x: node.x,
            y: node.y,
            width: size.width,
            height: size.height,
            offsetX: Double(offset.width),
            offsetY: Double(offset.height),
            zoom: effectiveZoom,
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY
        )
    }

    private func nodeSize(for node: CanvasNodeModel) -> (width: Double, height: Double) {
        switch node.nodeType {
        case .groupFrame:
            if let size = transientFrameSizes[node.id] {
                return (Double(size.width), Double(size.height))
            }
            return (max(node.width, CanvasNodeMetrics.frameWidth), max(node.height, CanvasNodeMetrics.frameHeight))
        case .note:
            return (CanvasNodeMetrics.cardWidth, CanvasNodeMetrics.noteHeight)
        case .resource, .snippet:
            return (CanvasNodeMetrics.cardWidth, CanvasNodeMetrics.cardHeight)
        }
    }

    private func frameRect(for node: CanvasNodeModel) -> CanvasFrameRect {
        let size = nodeSize(for: node)
        return CanvasFrameRect(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
    }

    private var selectionSummary: String {
        if selectedNodeIDs.isEmpty {
            return "Select a card to open, copy, alias, or delete it."
        }
        if selectedNodeIDs.count == 1, let node = selectedNode {
            return node.title
        }
        return "\(selectedNodeIDs.count) cards selected"
    }

    private var connectionSummary: String {
        if mode == .connect {
            if let source = connectionSourceNode {
                return "Connect mode: click the target card for \(source.title)."
            }
            return "Connect mode: click the first card, then the target card."
        }
        return "Use Connect mode or select two cards."
    }

    private var selectedNode: CanvasNodeModel? {
        guard selectedNodeIDs.count == 1, let id = selectedNodeIDs.first else { return nil }
        return workflowNodeById[id]
    }

    private var connectionSourceNode: CanvasNodeModel? {
        guard let connectionSourceNodeId else { return nil }
        return workflowNodeById[connectionSourceNodeId]
    }

    private var selectedResource: ResourcePinModel? {
        guard let node = selectedNode, node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    private var selectedSnippet: SnippetModel? {
        guard let node = selectedNode, node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    private func resource(for node: CanvasNodeModel) -> ResourcePinModel? {
        guard node.objectType == "resourcePin", let objectId = node.objectId else { return nil }
        return resourcesById[objectId]
    }

    private func snippet(for node: CanvasNodeModel) -> SnippetModel? {
        guard node.objectType == "snippet", let objectId = node.objectId else { return nil }
        return snippetsById[objectId]
    }

    private func dragGesture(for node: CanvasNodeModel) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizingFrameNodeId == node.id {
                    return
                }
                if nodeDragStart.isEmpty {
                    for draggedNode in draggedNodes(for: node) {
                        nodeDragStart[draggedNode.id] = CGPoint(x: CGFloat(draggedNode.x), y: CGFloat(draggedNode.y))
                    }
                    selectedNodeIDs = [node.id]
                }
                let delta = CGSize(width: value.translation.width / zoom, height: value.translation.height / zoom)
                for id in nodeDragStart.keys {
                    transientNodeOffsets[id] = delta
                }
            }
            .onEnded { value in
                if resizingFrameNodeId == node.id {
                    return
                }
                let delta = CGSize(width: value.translation.width / zoom, height: value.translation.height / zoom)
                for (id, start) in nodeDragStart {
                    guard let movedNode = workflowNodeById[id] else { continue }
                    movedNode.x = Double(start.x + delta.width)
                    movedNode.y = Double(start.y + delta.height)
                    movedNode.updatedAt = .now
                    transientNodeOffsets[id] = nil
                }
                for id in nodeDragStart.keys {
                    guard let movedNode = workflowNodeById[id], movedNode.nodeType != .groupFrame else { continue }
                    movedNode.parentNodeId = containingFrameId(for: movedNode)
                }
                nodeDragStart.removeAll()
                try? modelContext.save()
            }
    }

    private func draggedNodes(for node: CanvasNodeModel) -> [CanvasNodeModel] {
        guard node.nodeType == .groupFrame else { return [node] }

        let cards = renderSnapshot.cardNodes
        let candidates = cards.map(frameRect(for:))
        let childIDs = Set(CanvasFrameGeometry.childNodeIDs(inside: frameRect(for: node), candidates: candidates))
        let children = cards.filter { childIDs.contains($0.id) || $0.parentNodeId == node.id }
        return [node] + children
    }

    private func containingFrameId(for node: CanvasNodeModel) -> String? {
        let candidate = frameRect(for: node)
        let frames = workflowNodes
            .filter { $0.nodeType == .groupFrame }
            .map(frameRect(for:))
        return CanvasFrameGeometry.containingFrameId(for: candidate, frames: frames)
    }

    private func resizeFrame(_ node: CanvasNodeModel, screenTranslation: CGSize, commit: Bool) {
        guard node.nodeType == .groupFrame else { return }
        resizingFrameNodeId = node.id
        if frameResizeStartSizes[node.id] == nil {
            let size = nodeSize(for: node)
            frameResizeStartSizes[node.id] = CGSize(width: size.width, height: size.height)
        }
        guard let startSize = frameResizeStartSizes[node.id] else { return }

        let startFrame = CanvasFrameRect(
            id: node.id,
            x: node.x,
            y: node.y,
            width: Double(startSize.width),
            height: Double(startSize.height)
        )
        let resized = CanvasFrameGeometry.resizedFrame(
            startFrame,
            deltaWidth: Double(screenTranslation.width) / effectiveZoom,
            deltaHeight: Double(screenTranslation.height) / effectiveZoom,
            minimumWidth: CanvasNodeMetrics.frameMinWidth,
            minimumHeight: CanvasNodeMetrics.frameMinHeight
        )

        if commit {
            node.width = resized.width
            node.height = resized.height
            node.updatedAt = .now
            transientFrameSizes[node.id] = nil
            frameResizeStartSizes[node.id] = nil
            resizingFrameNodeId = nil
            selectedNodeIDs = [node.id]
            try? modelContext.save()
            onStatus("Resized organization frame")
        } else {
            transientFrameSizes[node.id] = CGSize(width: resized.width, height: resized.height)
        }
    }

    private func backgroundDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if mode == .boxSelect {
                    selectionRect = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    )
                } else {
                    transientViewportOffset = value.translation
                }
            }
            .onEnded { _ in
                if let rect = selectionRect {
                    selectedNodeIDs = Set(workflowNodes.filter { rect.contains(screenPoint(for: $0)) }.map(\.id))
                    selectionRect = nil
                    onStatus("Selected \(selectedNodeIDs.count) cards")
                } else if transientViewportOffset != .zero {
                    canvas.viewportX += Double(transientViewportOffset.width)
                    canvas.viewportY += Double(transientViewportOffset.height)
                    canvas.updatedAt = .now
                    try? modelContext.save()
                }
                transientViewportOffset = .zero
            }
    }

    private func handleNodeTap(_ node: CanvasNodeModel) {
        if suppressedTapNodeId == node.id {
            suppressedTapNodeId = nil
            return
        }
        switch mode {
        case .connect:
            connectByTap(node)
        case .select, .boxSelect:
            if selectedNodeIDs.contains(node.id), selectedNodeIDs.count > 1 {
                selectedNodeIDs.remove(node.id)
            } else {
                selectedNodeIDs = [node.id]
            }
            connectionSourceNodeId = nil
        }
    }

    private func connectByTap(_ node: CanvasNodeModel) {
        if let sourceId = connectionSourceNodeId {
            if sourceId == node.id {
                connectionSourceNodeId = nil
                selectedNodeIDs = [node.id]
                onStatus("Connection source cleared")
                return
            }
            createEdge(from: sourceId, to: node.id)
            selectedNodeIDs = [sourceId, node.id]
            connectionSourceNodeId = nil
            return
        }

        connectionSourceNodeId = node.id
        selectedNodeIDs = [node.id]
        onStatus("Choose a target card to connect from \(node.title)")
    }

    private func setZoom(_ value: Double) {
        canvas.zoom = CanvasZoomScale.clamped(
            value,
            minimum: CanvasNodeMetrics.zoomMinimum,
            maximum: CanvasNodeMetrics.zoomMaximum
        )
        canvas.updatedAt = .now
        try? modelContext.save()
    }

    private func openSelectedNode() {
        guard let selectedNode else { return }
        open(selectedNode)
    }

    private func copySelectedNode() {
        guard let selectedNode else { return }
        copyNodePayload(selectedNode)
    }

    private func open(_ node: CanvasNodeModel) {
        guard let resource = resource(for: node) else {
            if let snippet = snippet(for: node) {
                ClipboardService().copy(snippet.body)
                snippet.lastCopiedAt = .now
                snippet.updatedAt = .now
                try? modelContext.save()
                selectedNodeIDs = [node.id]
                onStatus("Copied snippet: \(snippet.title)")
                return
            }
            selectedNodeIDs = [node.id]
            onStatus("Selected note: \(node.title)")
            return
        }
        let bookmarkService = BookmarkService()
        let resolved = bookmarkService.resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
        do {
            try bookmarkService.access(resolved.url) {
                switch ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw) {
                case .open:
                    try FinderService().open(resolved.url)
                case .reveal:
                    try FinderService().reveal(resolved.url)
                }
            }
            resource.lastOpenedAt = .now
            resource.status = resolved.stale ? .staleAuthorization : .available
            resource.updatedAt = .now
            try modelContext.save()
            onStatus("Opened \(resource.displayName) in Finder")
            selectedNodeIDs = [node.id]
        } catch {
            resource.status = .unavailable
            try? modelContext.save()
            onStatus(error.localizedDescription)
        }
    }

    private func inspect(_ node: CanvasNodeModel) {
        selectedNodeIDs = [node.id]
        if let resource = resource(for: node) {
            onInspect(.resource(resource.id))
            onStatus("Showing info for \(resource.displayName)")
        } else if let snippet = snippet(for: node) {
            onInspect(.snippet(snippet.id))
            onStatus("Showing info for \(snippet.title)")
        } else {
            onInspect(.node(node.id))
            onStatus("Showing info for \(node.title)")
        }
    }

    private func copyNodePayload(_ node: CanvasNodeModel) {
        if let resource = resource(for: node) {
            let resolved = BookmarkService().resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
            ClipboardService().copy(resolved.url.path)
            selectedNodeIDs = [node.id]
            onStatus("Copied path: \(resolved.url.path)")
        } else if let snippet = snippet(for: node) {
            ClipboardService().copy(snippet.body)
            snippet.lastCopiedAt = .now
            snippet.updatedAt = .now
            try? modelContext.save()
            selectedNodeIDs = [node.id]
            onStatus("Copied snippet: \(snippet.title)")
        } else {
            ClipboardService().copy(node.body.isEmpty ? node.title : node.body)
            selectedNodeIDs = [node.id]
            onStatus("Copied node text: \(node.title)")
        }
    }

    private func connectButtonTapped(_ node: CanvasNodeModel) {
        if connectionSourceNodeId == node.id {
            connectionSourceNodeId = nil
            selectedNodeIDs = [node.id]
            onStatus("Connection source cleared")
            return
        }

        if let sourceId = connectionSourceNodeId {
            createEdge(from: sourceId, to: node.id)
            selectedNodeIDs = [sourceId, node.id]
            connectionSourceNodeId = nil
        } else {
            connectionSourceNodeId = node.id
            selectedNodeIDs = [node.id]
            onStatus("Choose a target card for \(node.title)")
        }
    }

    private func performCardButtonAction(_ node: CanvasNodeModel, action: () -> Void) {
        suppressedTapNodeId = node.id
        action()
        DispatchQueue.main.async {
            if suppressedTapNodeId == node.id {
                suppressedTapNodeId = nil
            }
        }
    }

    private func createAliasForSelectedNode() {
        guard let resource = selectedResource else { return }
        let resolved = BookmarkService().resolveBookmark(resource.securityScopedBookmarkData, fallbackPath: resource.lastResolvedPath)
        guard let requestedAliasURL = FileDialogs.saveAlias(defaultName: "\(resource.title) alias") else { return }
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

    private func addResourceNode(_ resource: ResourcePinModel) {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: resource.effectiveName, body: resource.note, nodeType: .resource, objectType: "resourcePin", objectId: resource.id, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.cardHeight, collapsed: true)
        modelContext.insert(node)
        try? modelContext.save()
        selectedNodeIDs = [node.id]
        onStatus("Added resource node")
    }

    private func addSnippetNode(_ snippet: SnippetModel) {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: snippet.title, body: snippet.details, nodeType: .snippet, objectType: "snippet", objectId: snippet.id, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.cardHeight, collapsed: true)
        modelContext.insert(node)
        try? modelContext.save()
        selectedNodeIDs = [node.id]
        onStatus("Added snippet node")
    }

    private func addNoteNode() {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Note", body: "Write a workflow note here.", nodeType: .note, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.noteHeight, collapsed: false)
        modelContext.insert(node)
        try? modelContext.save()
        selectedNodeIDs = [node.id]
        onStatus("Added note card")
    }

    private func addFrameNode() {
        let point = nextNodePosition()
        let node = CanvasNodeModel(canvasId: canvas.id, title: "Organization Frame", body: "Describe this part of the workflow.", nodeType: .groupFrame, x: point.x, y: point.y, width: CanvasNodeMetrics.frameWidth, height: CanvasNodeMetrics.frameHeight, collapsed: false, zIndex: -10)
        modelContext.insert(node)
        try? modelContext.save()
        selectedNodeIDs = [node.id]
        onStatus("Added organization frame")
    }

    private func importDroppedResources(_ urls: [URL], at dropLocation: CGPoint) {
        guard !urls.isEmpty else { return }
        do {
            let summary = try ResourceImportService().importURLs(
                urls,
                existingResources: resources,
                into: modelContext,
                scope: .global,
                workspaceId: nil,
                pinImported: false,
                saveChanges: false
            )
            var addedIDs: [String] = []
            for (index, resource) in summary.resources.enumerated() {
                let point = dropNodePosition(at: dropLocation, offset: index)
                let node = CanvasNodeModel(canvasId: canvas.id, title: resource.effectiveName, body: resource.note, nodeType: .resource, objectType: "resourcePin", objectId: resource.id, x: point.x, y: point.y, width: CanvasNodeMetrics.cardWidth, height: CanvasNodeMetrics.cardHeight, collapsed: true)
                modelContext.insert(node)
                addedIDs.append(node.id)
            }
            try modelContext.save()
            selectedNodeIDs = Set(addedIDs)
            onStatus("Canvas drop: \(summary.statusText)")
        } catch {
            modelContext.rollback()
            onStatus(error.localizedDescription)
        }
    }

    private func dropNodePosition(at location: CGPoint, offset index: Int) -> (x: Double, y: Double) {
        let stagger = Double(index * 28)
        let origin = CanvasDropPlacement.cardOrigin(
            dropX: Double(location.x),
            dropY: Double(location.y),
            viewportX: effectiveViewportX,
            viewportY: effectiveViewportY,
            zoom: effectiveZoom,
            cardWidth: CanvasNodeMetrics.cardWidth,
            cardHeight: CanvasNodeMetrics.cardHeight
        )
        return (x: origin.x + stagger, y: origin.y + stagger)
    }

    private func connectSelected() {
        let ids = Array(selectedNodeIDs)
        guard ids.count == 2 else { return }
        createEdge(from: ids[0], to: ids[1])
    }

    private func createEdge(from sourceId: String, to targetId: String) {
        guard sourceId != targetId else { return }
        let identities = visibleEdges.map { CanvasEdgeIdentity(sourceNodeId: $0.sourceNodeId, targetNodeId: $0.targetNodeId) }
        let exists = CanvasEdgeIdentity.exists(sourceNodeId: sourceId, targetNodeId: targetId, in: identities)
        guard !exists else {
            onStatus("Cards are already connected in that direction")
            return
        }
        let edge = CanvasEdgeModel(canvasId: canvas.id, sourceNodeId: sourceId, targetNodeId: targetId, targetArrowRaw: "arrow", animated: shouldAnimateGlow, animationThemeRaw: canvas.linkAnimationThemeRaw)
        modelContext.insert(edge)
        try? modelContext.save()
        onStatus("Connected cards with arrow")
    }

    private func alignLeft() {
        let selected = workflowNodes.filter { selectedNodeIDs.contains($0.id) }
        let layout = selected.map { node in
            let size = nodeSize(for: node)
            return CanvasLayoutNode(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
        }
        apply(CanvasLayoutEngine.alignLeft(layout))
        onStatus("Aligned left")
    }

    private func alignTop() {
        let selected = workflowNodes.filter { selectedNodeIDs.contains($0.id) }
        let layout = selected.map { node in
            let size = nodeSize(for: node)
            return CanvasLayoutNode(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
        }
        apply(CanvasLayoutEngine.alignTop(layout))
        onStatus("Aligned top")
    }

    private func autoArrange() {
        let layout = workflowNodes.map { node in
            let size = nodeSize(for: node)
            return CanvasLayoutNode(id: node.id, x: node.x, y: node.y, width: size.width, height: size.height)
        }
        apply(CanvasLayoutEngine.autoArrange(layout, columns: 3, spacing: 56))
        onStatus("Auto arranged canvas")
    }

    private func apply(_ layout: [CanvasLayoutNode]) {
        for item in layout {
            guard let node = workflowNodeById[item.id] else { continue }
            node.x = item.x
            node.y = item.y
            node.updatedAt = .now
        }
        try? modelContext.save()
    }

    private func toggleNote(for node: CanvasNodeModel) {
        node.collapsed.toggle()
        node.updatedAt = .now
        try? modelContext.save()
    }

    private func delete(_ node: CanvasNodeModel) {
        selectedNodeIDs = [node.id]
        deleteSelectedNodes()
    }

    private func deleteSelectedNodes() {
        let ids = selectedNodeIDs
        guard !ids.isEmpty else { return }
        for edge in visibleEdges where ids.contains(edge.sourceNodeId) || ids.contains(edge.targetNodeId) {
            modelContext.delete(edge)
        }
        for node in workflowNodes where ids.contains(node.id) {
            modelContext.delete(node)
        }
        selectedNodeIDs = []
        connectionSourceNodeId = nil
        try? modelContext.save()
        onStatus("Deleted \(ids.count) card\(ids.count == 1 ? "" : "s")")
    }

    private func deleteSelectedConnections() {
        let ids = selectedNodeIDs
        guard !ids.isEmpty else { return }
        let removedEdges = visibleEdges.filter { edge in
            if ids.count >= 2 {
                return ids.contains(edge.sourceNodeId) && ids.contains(edge.targetNodeId)
            }
            return ids.contains(edge.sourceNodeId) || ids.contains(edge.targetNodeId)
        }
        for edge in removedEdges {
            modelContext.delete(edge)
        }
        try? modelContext.save()
        onStatus("Deleted \(removedEdges.count) link\(removedEdges.count == 1 ? "" : "s")")
    }

    private func nextNodePosition(offset additionalOffset: Int = 0) -> (x: Double, y: Double) {
        let index = workflowNodes.count + additionalOffset
        let offset = Double((index % 6) * 28)
        return (
            x: (96 - effectiveViewportX) / Double(zoom) + offset,
            y: (96 - effectiveViewportY) / Double(zoom) + offset
        )
    }
}

struct CanvasNodeCard: View {
    let node: CanvasNodeModel
    let resource: ResourcePinModel?
    let snippet: SnippetModel?
    let isSelected: Bool
    let isConnectionSource: Bool
    let isConnected: Bool
    let glowTheme: CanvasGlowTheme
    let animateGlow: Bool
    let glowPulse: Bool
    let onOpen: () -> Void
    let onInfo: () -> Void
    let onCopy: () -> Void
    let onConnect: () -> Void
    let onToggleNote: () -> Void
    let onDelete: () -> Void
    @State private var feedback: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Button {
                        triggerFeedback("Copied") {
                            onCopy()
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(CardIconButtonStyle())
                    .help(resource == nil ? "Copy text" : "Copy full path")
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(CardIconButtonStyle())
                    .help("Show details")
                    Button(action: onConnect) {
                        Image(systemName: isConnectionSource ? "link.circle.fill" : "link.circle")
                    }
                    .buttonStyle(CardIconButtonStyle(isActive: isConnectionSource))
                    .help(isConnectionSource ? "Clear connection source" : "Connect from or to this card")
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(CardIconButtonStyle())
                    .help("Delete card")
                }

                Text(titleText)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
                Spacer()

                Divider()
                    .opacity(0.45)
                Button(action: onToggleNote) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: node.collapsed ? "chevron.right" : "chevron.down")
                                .font(.caption2)
                            Text("Note")
                                .font(.caption.bold())
                            Spacer()
                        }
                        if !node.collapsed {
                            Text(node.body.isEmpty ? "No description yet." : node.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected || isConnectionSource ? 2 : 1)
            }
            .overlay {
                if isConnected && glowTheme != .off {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(glowColor.opacity(glowTheme == .blue ? 0.56 : 0.28), lineWidth: glowTheme == .blue ? 2 : 1)
                        .blur(radius: glowTheme == .blue ? 4 : 1)
                        .opacity(animateGlow ? (glowPulse ? 0.95 : 0.42) : 0.55)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: glowShadowColor, radius: glowShadowRadius, y: isSelected ? 2 : 1)

            if let feedback {
                Text(feedback)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.92))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(8)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .contextMenu {
            Button("Open") { onOpen() }
            Button("Copy") {
                triggerFeedback("Copied") {
                    onCopy()
                }
            }
            Button("Show Details") { onInfo() }
            Button("Connect") { onConnect() }
            Button("Toggle Note") { onToggleNote() }
            Button("Delete Card", role: .destructive) { onDelete() }
        }
    }

    private var borderColor: Color {
        if isConnectionSource {
            return .accentColor
        }
        return isSelected ? .accentColor : Color.secondary.opacity(0.25)
    }

    private var icon: String {
        if let resource {
            return resource.targetType == .folder ? "folder" : "doc"
        }
        if let snippet {
            return snippet.kind == .prompt ? "text.quote" : "terminal"
        }
        switch node.nodeType {
        case .resource:
            return "folder"
        case .snippet:
            return "text.quote"
        case .note:
            return "note.text"
        case .groupFrame:
            return "rectangle.dashed"
        }
    }

    private var titleText: String {
        if let resource {
            return resource.displayName
        }
        return node.title
    }

    private var subtitle: String {
        if let resource {
            return resource.targetType == .folder ? "Folder" : "File"
        }
        if let snippet {
            return snippet.kind == .prompt ? "Prompt" : "Command"
        }
        return node.nodeType.rawValue.capitalized
    }

    private var glowColor: Color {
        glowTheme == .blue ? .blue : .accentColor
    }

    private var glowShadowColor: Color {
        if isConnected && glowTheme == .blue {
            return .blue.opacity(0.22)
        }
        return .black.opacity(isSelected ? 0.18 : 0.08)
    }

    private var glowShadowRadius: CGFloat {
        if isConnected && glowTheme == .blue {
            return isSelected ? 9 : 6
        }
        return isSelected ? 5 : 1
    }

    private func triggerFeedback(_ message: String, action: () -> Void) {
        action()
        withAnimation(.easeOut(duration: 0.12)) {
            feedback = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard feedback == message else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                feedback = nil
            }
        }
    }

}

struct CardIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .frame(width: 22, height: 22)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.22 : 0.08), radius: configuration.isPressed ? 1 : 2, y: configuration.isPressed ? 0 : 1)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isActive {
            return Color.accentColor.opacity(isPressed ? 0.34 : 0.22)
        }
        return Color.secondary.opacity(isPressed ? 0.22 : 0.1)
    }
}

private struct CanvasFileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider], CGPoint) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [UTType.fileURL]).isEmpty
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.fileURL])
        guard !providers.isEmpty else {
            isTargeted = false
            return false
        }
        isTargeted = false
        onDrop(providers, info.location)
        return true
    }
}

struct CanvasFrameCard: View {
    let node: CanvasNodeModel
    let isSelected: Bool
    let isConnected: Bool
    let glowTheme: CanvasGlowTheme
    let animateGlow: Bool
    let glowPulse: Bool
    let isConnectionSource: Bool
    let onInfo: () -> Void
    let onCopy: () -> Void
    let onConnect: () -> Void
    let onDelete: () -> Void
    let onResizeChanged: (CGSize) -> Void
    let onResizeEnded: (CGSize) -> Void
    @State private var feedback: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.dashed")
                        .foregroundStyle(.secondary)
                    Text(node.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        triggerFeedback("Copied") {
                            onCopy()
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(CardIconButtonStyle())
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(CardIconButtonStyle())
                    Button(action: onConnect) {
                        Image(systemName: isConnectionSource ? "link.circle.fill" : "link.circle")
                    }
                    .buttonStyle(CardIconButtonStyle(isActive: isConnectionSource))
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(CardIconButtonStyle())
                }

                Text(node.body.isEmpty ? "No frame note yet." : node.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.045))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, style: StrokeStyle(lineWidth: isSelected || isConnectionSource ? 2 : 1.4, dash: [8, 5]))
            }
            .overlay {
                if isConnected && glowTheme != .off {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((glowTheme == .blue ? Color.blue : Color.accentColor).opacity(glowTheme == .blue ? 0.48 : 0.24), lineWidth: 2)
                        .blur(radius: glowTheme == .blue ? 5 : 1)
                        .opacity(animateGlow ? (glowPulse ? 0.9 : 0.38) : 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: isConnected && glowTheme == .blue ? .blue.opacity(0.16) : .black.opacity(isSelected ? 0.12 : 0.04), radius: isSelected ? 6 : 2, y: 1)

            if let feedback {
                Text(feedback)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.92))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(8)
                    .transition(.opacity.combined(with: .scale))
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FrameResizeHandle()
                        .padding(6)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    onResizeChanged(value.translation)
                                }
                                .onEnded { value in
                                    onResizeEnded(value.translation)
                                }
                        )
                }
            }
        }
        .contextMenu {
            Button("Copy Note") {
                triggerFeedback("Copied") {
                    onCopy()
                }
            }
            Button("Show Details", action: onInfo)
            Button("Connect", action: onConnect)
            Button("Delete Frame", role: .destructive, action: onDelete)
        }
    }

    private var borderColor: Color {
        if isConnectionSource {
            return .accentColor
        }
        return isSelected ? .accentColor : Color.secondary.opacity(0.45)
    }

    private func triggerFeedback(_ message: String, action: () -> Void) {
        action()
        withAnimation(.easeOut(duration: 0.12)) {
            feedback = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard feedback == message else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                feedback = nil
            }
        }
    }

}

struct FlowingArrowEdge: View {
    let start: CGPoint
    let end: CGPoint
    let theme: CanvasGlowTheme
    let isAnimated: Bool
    let canvasSize: CGSize

    var body: some View {
        Group {
            if isAnimated {
                TimelineView(.animation) { context in
                    edgeCanvas(
                        dashPhase: CanvasEdgeFlowPhase.dashPhase(
                            elapsed: context.date.timeIntervalSinceReferenceDate,
                            duration: 1.6,
                            cycleLength: 172
                        )
                    )
                }
            } else {
                edgeCanvas(dashPhase: nil)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var flowColor: Color {
        theme == .blue ? .blue : .accentColor
    }

    private func edgeCanvas(dashPhase: Double?) -> some View {
        Canvas { context, _ in
            let curve = EdgePathFactory.curve(start: start, end: end)

            context.stroke(
                curve,
                with: .color(Color.secondary.opacity(0.36)),
                style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
            )

            if let dashPhase {
                context.stroke(
                    curve,
                    with: .color(flowColor.opacity(theme == .blue ? 1 : 0.9)),
                    style: StrokeStyle(lineWidth: theme == .blue ? 3.4 : 2.4, lineCap: .round, lineJoin: .round, dash: [24, 148], dashPhase: dashPhase)
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

struct FlowingArrowHead: View {
    let start: CGPoint
    let end: CGPoint
    let theme: CanvasGlowTheme
    let isAnimated: Bool
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, _ in
            let arrow = EdgePathFactory.arrowHead(start: start, end: end)
            context.fill(arrow, with: .color(arrowColor))
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var arrowColor: Color {
        guard isAnimated, theme != .off else {
            return Color.primary.opacity(0.72)
        }
        return (theme == .blue ? Color.blue : Color.accentColor).opacity(1)
    }
}

private struct FrameResizeHandle: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.background.opacity(0.78))
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .frame(width: 22, height: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.32), lineWidth: 1)
        }
        .help("Resize frame")
    }
}

private enum EdgePathFactory {
    static func curve(start: CGPoint, end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        if usesHorizontalRoute(start: start, end: end) {
            let midX = (start.x + end.x) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: midX, y: start.y),
                control2: CGPoint(x: midX, y: end.y)
            )
        } else {
            let midY = (start.y + end.y) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: midY),
                control2: CGPoint(x: end.x, y: midY)
            )
        }
        return path
    }

    static func arrowHead(start: CGPoint, end: CGPoint) -> Path {
        let angle = terminalAngle(start: start, end: end)
        let arrowLength: CGFloat = 13
        let halfWidth: CGFloat = 5.5
        let baseCenter = CGPoint(
            x: end.x - arrowLength * cos(angle),
            y: end.y - arrowLength * sin(angle)
        )
        let normal = angle + .pi / 2
        let left = CGPoint(
            x: baseCenter.x + halfWidth * cos(normal),
            y: baseCenter.y + halfWidth * sin(normal)
        )
        let right = CGPoint(
            x: baseCenter.x - halfWidth * cos(normal),
            y: baseCenter.y - halfWidth * sin(normal)
        )

        var path = Path()
        path.move(to: end)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private static func usesHorizontalRoute(start: CGPoint, end: CGPoint) -> Bool {
        abs(end.x - start.x) >= abs(end.y - start.y)
    }

    private static func terminalAngle(start: CGPoint, end: CGPoint) -> CGFloat {
        if usesHorizontalRoute(start: start, end: end) {
            return end.x >= start.x ? 0 : .pi
        }
        return end.y >= start.y ? .pi / 2 : -.pi / 2
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 32
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        return path
    }
}
