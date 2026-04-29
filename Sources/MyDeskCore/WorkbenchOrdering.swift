import Foundation

public struct WorkspaceSidebarOrderRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var isPinned: Bool
    public var sortIndex: Int
    public var updatedAt: Date

    public init(id: String, isPinned: Bool, sortIndex: Int, updatedAt: Date) {
        self.id = id
        self.isPinned = isPinned
        self.sortIndex = sortIndex
        self.updatedAt = updatedAt
    }
}

public enum SidebarMoveDirection: Sendable {
    case up
    case down
}

public enum WorkspaceSidebarOrdering {
    public static func ordered(_ records: [WorkspaceSidebarOrderRecord]) -> [WorkspaceSidebarOrderRecord] {
        records.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.id < rhs.id
        }
    }

    public static func movedIDs(
        _ ids: [String],
        moving id: String,
        direction: SidebarMoveDirection
    ) -> [String] {
        guard let index = ids.firstIndex(of: id) else { return ids }
        var moved = ids
        switch direction {
        case .up:
            guard index > moved.startIndex else { return ids }
            moved.swapAt(index, moved.index(before: index))
        case .down:
            let nextIndex = moved.index(after: index)
            guard nextIndex < moved.endIndex else { return ids }
            moved.swapAt(index, nextIndex)
        }
        return moved
    }
}

public struct ResourceLibraryRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var targetType: String
    public var title: String
    public var originalName: String
    public var customName: String
    public var displayPath: String
    public var isPinned: Bool
    public var updatedAt: Date
    public var sortIndex: Int

    public init(
        id: String,
        targetType: String,
        title: String,
        originalName: String,
        customName: String,
        displayPath: String,
        isPinned: Bool,
        updatedAt: Date = Date(timeIntervalSince1970: 0),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.targetType = targetType
        self.title = title
        self.originalName = originalName
        self.customName = customName
        self.displayPath = displayPath
        self.isPinned = isPinned
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
    }

    public var displayName: String {
        let trimmedOriginal = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCustom = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedOriginal.isEmpty ? fallback : trimmedOriginal

        guard !trimmedCustom.isEmpty, trimmedCustom != base else {
            return base
        }
        return "\(base) · \(trimmedCustom)"
    }
}

public enum ResourceLibraryFiltering {
    public static func folders(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.targetType == "folder" })
    }

    public static func files(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.targetType == "file" })
    }

    public static func pinnedFolders(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.isPinned && $0.targetType == "folder" })
    }

    public static func pinnedFiles(in records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        ordered(records.filter { $0.isPinned && $0.targetType == "file" })
    }

    public static func ordered(_ records: [ResourceLibraryRecord]) -> [ResourceLibraryRecord] {
        records.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex {
                return lhs.sortIndex < rhs.sortIndex
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            let nameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }
}

public enum ResourceFinderAction: Equatable, Sendable {
    case open
    case reveal
}

public enum ResourceFinderRouting {
    public static func doubleClickAction(forTargetType targetType: String) -> ResourceFinderAction {
        targetType == "file" ? .reveal : .open
    }
}

public struct FolderPreviewItemRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var isDirectory: Bool

    public init(id: String, name: String, isDirectory: Bool) {
        self.id = id
        self.name = name
        self.isDirectory = isDirectory
    }
}

public enum FolderPreviewOrdering {
    public static func ordered(_ records: [FolderPreviewItemRecord]) -> [FolderPreviewItemRecord] {
        records.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }
}

public enum CanvasEdgeAnimationPolicy {
    public static func shouldAnimateEdge(
        theme: String,
        animationsEnabled: Bool,
        reduceMotion: Bool,
        edgeCount: Int
    ) -> Bool {
        animationsEnabled &&
        !reduceMotion &&
        theme != "off" &&
        edgeCount > 0 &&
        edgeCount <= 120
    }
}

public struct CanvasEdgeIdentity: Equatable, Sendable {
    public var sourceNodeId: String
    public var targetNodeId: String

    public init(sourceNodeId: String, targetNodeId: String) {
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
    }

    public static func exists(
        sourceNodeId: String,
        targetNodeId: String,
        in edges: [CanvasEdgeIdentity]
    ) -> Bool {
        edges.contains { $0.sourceNodeId == sourceNodeId && $0.targetNodeId == targetNodeId }
    }
}

public struct CanvasFrameRect: Equatable, Identifiable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct CanvasEdgePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CanvasEdgeAnchorPair: Equatable, Sendable {
    public var start: CanvasEdgePoint
    public var end: CanvasEdgePoint

    public init(start: CanvasEdgePoint, end: CanvasEdgePoint) {
        self.start = start
        self.end = end
    }
}

public enum CanvasEdgeAnchoring {
    public static func anchors(
        source: CanvasFrameRect,
        target: CanvasFrameRect,
        targetClearance: Double = 0
    ) -> CanvasEdgeAnchorPair {
        let sourceCenterX = source.x + source.width / 2
        let sourceCenterY = source.y + source.height / 2
        let targetCenterX = target.x + target.width / 2
        let targetCenterY = target.y + target.height / 2
        let dx = targetCenterX - sourceCenterX
        let dy = targetCenterY - sourceCenterY

        if abs(dx) >= abs(dy) {
            if dx >= 0 {
                return CanvasEdgeAnchorPair(
                    start: CanvasEdgePoint(x: source.x + source.width, y: sourceCenterY),
                    end: CanvasEdgePoint(x: target.x - targetClearance, y: targetCenterY)
                )
            }
            return CanvasEdgeAnchorPair(
                start: CanvasEdgePoint(x: source.x, y: sourceCenterY),
                end: CanvasEdgePoint(x: target.x + target.width + targetClearance, y: targetCenterY)
            )
        }

        if dy >= 0 {
            return CanvasEdgeAnchorPair(
                start: CanvasEdgePoint(x: sourceCenterX, y: source.y + source.height),
                end: CanvasEdgePoint(x: targetCenterX, y: target.y - targetClearance)
            )
        }
        return CanvasEdgeAnchorPair(
            start: CanvasEdgePoint(x: sourceCenterX, y: source.y),
            end: CanvasEdgePoint(x: targetCenterX, y: target.y + target.height + targetClearance)
        )
    }
}

public enum CanvasViewportProjection {
    public static func screenPoint(
        id: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        offsetX: Double = 0,
        offsetY: Double = 0,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasEdgePoint {
        CanvasEdgePoint(
            x: (x + offsetX + width / 2) * zoom + viewportX,
            y: (y + offsetY + height / 2) * zoom + viewportY
        )
    }

    public static func screenRect(
        id: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        offsetX: Double = 0,
        offsetY: Double = 0,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasFrameRect {
        CanvasFrameRect(
            id: id,
            x: (x + offsetX) * zoom + viewportX,
            y: (y + offsetY) * zoom + viewportY,
            width: width * zoom,
            height: height * zoom
        )
    }
}

public enum CanvasEdgeFlowPhase {
    public static func dashPhase(elapsed: Double, duration: Double, cycleLength: Double) -> Double {
        guard duration > 0, cycleLength > 0 else { return 0 }
        let progress = elapsed.truncatingRemainder(dividingBy: duration) / duration
        return -cycleLength * progress
    }
}

public struct CanvasFramePosition: Equatable, Identifiable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double

    public init(id: String, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

public enum CanvasFrameGeometry {
    public static func childNodeIDs(
        inside frame: CanvasFrameRect,
        candidates: [CanvasFrameRect]
    ) -> [String] {
        candidates
            .filter { candidate in
                candidate.id != frame.id &&
                candidate.x >= frame.x &&
                candidate.y >= frame.y &&
                candidate.x + candidate.width <= frame.x + frame.width &&
                candidate.y + candidate.height <= frame.y + frame.height
            }
            .map(\.id)
    }

    public static func movedPositions(
        _ positions: [CanvasFramePosition],
        movingFrameId: String,
        childNodeIDs: [String],
        deltaX: Double,
        deltaY: Double
    ) -> [CanvasFramePosition] {
        let movedIDs = Set(childNodeIDs).union([movingFrameId])
        return positions.map { position in
            guard movedIDs.contains(position.id) else { return position }
            return CanvasFramePosition(id: position.id, x: position.x + deltaX, y: position.y + deltaY)
        }
    }

    public static func resizedFrame(
        _ frame: CanvasFrameRect,
        deltaWidth: Double,
        deltaHeight: Double,
        minimumWidth: Double,
        minimumHeight: Double
    ) -> CanvasFrameRect {
        CanvasFrameRect(
            id: frame.id,
            x: frame.x,
            y: frame.y,
            width: max(minimumWidth, frame.width + deltaWidth),
            height: max(minimumHeight, frame.height + deltaHeight)
        )
    }

    public static func containingFrameId(for candidate: CanvasFrameRect, frames: [CanvasFrameRect]) -> String? {
        frames
            .filter { frame in
                candidate.id != frame.id &&
                candidate.x >= frame.x &&
                candidate.y >= frame.y &&
                candidate.x + candidate.width <= frame.x + frame.width &&
                candidate.y + candidate.height <= frame.y + frame.height
            }
            .sorted {
                let lhsArea = $0.width * $0.height
                let rhsArea = $1.width * $1.height
                if lhsArea != rhsArea {
                    return lhsArea < rhsArea
                }
                return $0.id < $1.id
            }
            .first?
            .id
    }
}

public enum CanvasDropPlacement {
    public static func cardOrigin(
        dropX: Double,
        dropY: Double,
        viewportX: Double,
        viewportY: Double,
        zoom: Double,
        cardWidth: Double,
        cardHeight: Double
    ) -> (x: Double, y: Double) {
        let safeZoom = max(zoom, 0.01)
        return (
            x: (dropX - viewportX) / safeZoom - cardWidth / 2,
            y: (dropY - viewportY) / safeZoom - cardHeight / 2
        )
    }
}

public enum CanvasZoomScale {
    public static func clamped(_ zoom: Double, minimum: Double, maximum: Double) -> Double {
        min(max(zoom, minimum), maximum)
    }

    public static func displayPercent(forZoom zoom: Double, baseline: Double) -> Int {
        guard baseline > 0 else { return 100 }
        return Int((zoom / baseline * 100).rounded())
    }

    public static func zoom(
        forDisplayScale displayScale: Double,
        baseline: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        clamped(displayScale * baseline, minimum: minimum, maximum: maximum)
    }
}
