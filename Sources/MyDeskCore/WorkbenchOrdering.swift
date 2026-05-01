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

public enum WorkbenchSidebarMetrics {
    public static let minimumWidth: Double = 208
    public static let idealWidth: Double = 224
    public static let maximumWidth: Double = 300
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

public struct SnippetLibraryRecord: Equatable, Identifiable, Sendable {
    public var id: String
    public var scope: String
    public var workspaceId: String?
    public var title: String
    public var updatedAt: Date

    public init(id: String, scope: String, workspaceId: String?, title: String, updatedAt: Date) {
        self.id = id
        self.scope = scope
        self.workspaceId = workspaceId
        self.title = title
        self.updatedAt = updatedAt
    }
}

public enum SnippetLibraryFiltering {
    public static func visible(
        _ records: [SnippetLibraryRecord],
        scope: String?,
        workspaceId: String?
    ) -> [SnippetLibraryRecord] {
        let filtered = records.filter { record in
            guard let scope else { return true }
            if scope == "global" {
                return record.scope == "global"
            }
            return record.scope == "global" || record.workspaceId == workspaceId
        }
        return ordered(filtered)
    }

    public static func ordered(_ records: [SnippetLibraryRecord]) -> [SnippetLibraryRecord] {
        records.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            let nameComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return lhs.id < rhs.id
        }
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

public struct CanvasNodeSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum CanvasNodeSizePolicy {
    public static func size(
        kind _: String,
        storedWidth: Double,
        storedHeight: Double,
        defaultWidth: Double,
        defaultHeight: Double,
        minimumWidth: Double,
        minimumHeight: Double
    ) -> CanvasNodeSize {
        let widthBase = storedWidth > 0 ? storedWidth : defaultWidth
        let heightBase = storedHeight > 0 ? storedHeight : defaultHeight
        return CanvasNodeSize(
            width: max(widthBase, minimumWidth),
            height: max(heightBase, minimumHeight)
        )
    }
}

public enum CanvasCardTitleLayoutPolicy {
    public static func maxTitleHeight(kind: String, cardHeight: Double) -> Double {
        let safeHeight = max(cardHeight, 0)
        if kind == "note" {
            return min(36, max(18, safeHeight * 0.10))
        }
        return min(70, max(30, safeHeight * 0.20))
    }

    public static func minTitleHeight(kind: String) -> Double {
        kind == "note" ? 18 : 24
    }
}

public enum CanvasChromeTextRole: Sendable {
    case cardHeader
    case cardDetailLabel
    case cardDetailBody
    case frameNote
}

public enum CanvasChromeRenderingPolicy {
    public static func requiresNativeDrawing(_ role: CanvasChromeTextRole) -> Bool {
        switch role {
        case .cardHeader, .cardDetailLabel, .cardDetailBody, .frameNote:
            return true
        }
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
    public var startDirection: CanvasEdgePoint
    public var endDirection: CanvasEdgePoint

    public init(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint = CanvasEdgePoint(x: 1, y: 0),
        endDirection: CanvasEdgePoint = CanvasEdgePoint(x: 1, y: 0)
    ) {
        self.start = start
        self.end = end
        self.startDirection = startDirection
        self.endDirection = endDirection
    }
}

public struct CanvasEdgeCubicControls: Equatable, Sendable {
    public var control1: CanvasEdgePoint
    public var control2: CanvasEdgePoint

    public init(control1: CanvasEdgePoint, control2: CanvasEdgePoint) {
        self.control1 = control1
        self.control2 = control2
    }
}

public struct CanvasEdgeControlSegments: Equatable, Sendable {
    public var first: CanvasEdgeCubicControls
    public var second: CanvasEdgeCubicControls

    public init(first: CanvasEdgeCubicControls, second: CanvasEdgeCubicControls) {
        self.first = first
        self.second = second
    }
}

public enum CanvasEdgeAnchoring {
    private struct ResolvedAnchor {
        var point: CanvasEdgePoint
        var outwardDirection: CanvasEdgePoint
    }

    public static func anchors(
        source: CanvasFrameRect,
        target: CanvasFrameRect,
        control: CanvasEdgePoint? = nil,
        targetClearance: Double = 0
    ) -> CanvasEdgeAnchorPair {
        let sourceToward = control ?? center(of: target)
        let targetToward = control ?? center(of: source)
        let sourceAnchor = anchor(on: source, toward: sourceToward)
        let targetAnchor = anchor(on: target, toward: targetToward, clearance: targetClearance)

        return CanvasEdgeAnchorPair(
            start: sourceAnchor.point,
            end: targetAnchor.point,
            startDirection: sourceAnchor.outwardDirection,
            endDirection: CanvasEdgePoint(x: -targetAnchor.outwardDirection.x, y: -targetAnchor.outwardDirection.y)
        )
    }

    private static func center(of rect: CanvasFrameRect) -> CanvasEdgePoint {
        CanvasEdgePoint(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2)
    }

    private static func anchor(
        on rect: CanvasFrameRect,
        toward point: CanvasEdgePoint,
        clearance: Double = 0
    ) -> ResolvedAnchor {
        let center = center(of: rect)
        let dx = point.x - center.x
        let dy = point.y - center.y

        if abs(dx) >= abs(dy) {
            return dx >= 0
                ? ResolvedAnchor(
                    point: CanvasEdgePoint(x: rect.x + rect.width + clearance, y: center.y),
                    outwardDirection: CanvasEdgePoint(x: 1, y: 0)
                )
                : ResolvedAnchor(
                    point: CanvasEdgePoint(x: rect.x - clearance, y: center.y),
                    outwardDirection: CanvasEdgePoint(x: -1, y: 0)
                )
        }

        return dy >= 0
            ? ResolvedAnchor(
                point: CanvasEdgePoint(x: center.x, y: rect.y + rect.height + clearance),
                outwardDirection: CanvasEdgePoint(x: 0, y: 1)
            )
            : ResolvedAnchor(
                point: CanvasEdgePoint(x: center.x, y: rect.y - clearance),
                outwardDirection: CanvasEdgePoint(x: 0, y: -1)
            )
    }
}

public enum CanvasEdgeCurveGeometry {
    public static func automaticControls(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint
    ) -> CanvasEdgeCubicControls {
        let distance = distance(start, end)
        let handle = handleLength(for: distance)
        let startVector = normalized(startDirection, fallback: vector(from: start, to: end))
        let endVector = normalized(endDirection, fallback: vector(from: start, to: end))

        return CanvasEdgeCubicControls(
            control1: CanvasEdgePoint(
                x: start.x + startVector.x * handle,
                y: start.y + startVector.y * handle
            ),
            control2: CanvasEdgePoint(
                x: end.x - endVector.x * handle,
                y: end.y - endVector.y * handle
            )
        )
    }

    public static func controlsThroughPoint(
        start: CanvasEdgePoint,
        control: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint
    ) -> CanvasEdgeControlSegments {
        let incoming = normalized(vector(from: start, to: control), fallback: vector(from: start, to: end))
        let outgoing = normalized(vector(from: control, to: end), fallback: vector(from: start, to: end))
        let tangent = normalized(
            CanvasEdgePoint(x: incoming.x + outgoing.x, y: incoming.y + outgoing.y),
            fallback: vector(from: start, to: end)
        )
        let firstDistance = distance(start, control)
        let secondDistance = distance(control, end)
        let firstStartHandle = handleLength(for: firstDistance)
        let firstEndHandle = handleLength(for: firstDistance)
        let secondStartHandle = handleLength(for: secondDistance)
        let secondEndHandle = handleLength(for: secondDistance)
        let startVector = normalized(startDirection, fallback: vector(from: start, to: control))
        let endVector = normalized(endDirection, fallback: vector(from: control, to: end))

        return CanvasEdgeControlSegments(
            first: CanvasEdgeCubicControls(
                control1: CanvasEdgePoint(
                    x: start.x + startVector.x * firstStartHandle,
                    y: start.y + startVector.y * firstStartHandle
                ),
                control2: CanvasEdgePoint(
                    x: control.x - tangent.x * firstEndHandle,
                    y: control.y - tangent.y * firstEndHandle
                )
            ),
            second: CanvasEdgeCubicControls(
                control1: CanvasEdgePoint(
                    x: control.x + tangent.x * secondStartHandle,
                    y: control.y + tangent.y * secondStartHandle
                ),
                control2: CanvasEdgePoint(
                    x: end.x - endVector.x * secondEndHandle,
                    y: end.y - endVector.y * secondEndHandle
                )
            )
        )
    }

    public static func terminalAngleRadians(endDirection: CanvasEdgePoint) -> Double {
        let direction = normalized(endDirection, fallback: CanvasEdgePoint(x: 1, y: 0))
        return atan2(direction.y, direction.x)
    }

    private static func handleLength(for distance: Double) -> Double {
        guard distance > 0 else { return 0 }
        let maximum = min(140, distance * 0.5)
        let minimum = min(28, maximum)
        return min(max(distance * 0.42, minimum), maximum)
    }

    private static func distance(_ lhs: CanvasEdgePoint, _ rhs: CanvasEdgePoint) -> Double {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func vector(from start: CanvasEdgePoint, to end: CanvasEdgePoint) -> CanvasEdgePoint {
        CanvasEdgePoint(x: end.x - start.x, y: end.y - start.y)
    }

    private static func normalized(_ vector: CanvasEdgePoint, fallback: CanvasEdgePoint) -> CanvasEdgePoint {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y)
        if length > 0.0001 {
            return CanvasEdgePoint(x: vector.x / length, y: vector.y / length)
        }

        let fallbackLength = sqrt(fallback.x * fallback.x + fallback.y * fallback.y)
        if fallbackLength > 0.0001 {
            return CanvasEdgePoint(x: fallback.x / fallbackLength, y: fallback.y / fallbackLength)
        }

        return CanvasEdgePoint(x: 1, y: 0)
    }
}

public enum CanvasEdgeRoutePlanner {
    public static func routePoints(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        waypoints: [CanvasEdgePoint],
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint,
        obstacles: [CanvasFrameRect],
        clearance: Double = 24
    ) -> [CanvasEdgePoint] {
        guard !waypoints.isEmpty else {
            return routePoints(
                start: start,
                end: end,
                startDirection: startDirection,
                endDirection: endDirection,
                obstacles: obstacles,
                clearance: clearance
            )
        }

        let requiredPoints = [start] + waypoints + [end]
        guard polylineIntersectsObstacles(requiredPoints, obstacles: obstacles, clearance: clearance) else {
            return []
        }

        var route: [CanvasEdgePoint] = []
        for index in requiredPoints.indices.dropLast() {
            let segmentStart = requiredPoints[index]
            let segmentEnd = requiredPoints[index + 1]
            let segmentStartDirection = index == requiredPoints.startIndex
                ? startDirection
                : vector(from: segmentStart, to: segmentEnd)
            let segmentEndDirection = index == requiredPoints.index(before: requiredPoints.endIndex) - 1
                ? endDirection
                : vector(from: segmentStart, to: segmentEnd)
            route.append(contentsOf: routePoints(
                start: segmentStart,
                end: segmentEnd,
                startDirection: segmentStartDirection,
                endDirection: segmentEndDirection,
                obstacles: obstacles,
                clearance: clearance
            ))
            if index + 1 < requiredPoints.index(before: requiredPoints.endIndex) {
                route.append(segmentEnd)
            }
        }

        return route
    }

    public static func routePoints(
        start: CanvasEdgePoint,
        end: CanvasEdgePoint,
        startDirection: CanvasEdgePoint,
        endDirection: CanvasEdgePoint,
        obstacles: [CanvasFrameRect],
        clearance: Double = 24
    ) -> [CanvasEdgePoint] {
        guard polylineIntersectsObstacles([start, end], obstacles: obstacles, clearance: clearance) else {
            return []
        }

        let expandedObstacles = obstacles.map { expanded($0, by: clearance) }
        let blockingObstacles = expandedObstacles.filter { segmentIntersectsRect(start, end, $0) }
        let routeObstacles = blockingObstacles.isEmpty ? expandedObstacles : blockingObstacles
        let lead = max(28, clearance * 1.25)
        let sourceLead = safeLead(
            from: start,
            direction: startDirection,
            distance: lead,
            avoiding: expandedObstacles
        )
        let targetLead = safeLead(
            from: end,
            direction: CanvasEdgePoint(x: -endDirection.x, y: -endDirection.y),
            distance: lead,
            avoiding: expandedObstacles
        )
        var candidates: [[CanvasEdgePoint]] = []

        for obstacle in routeObstacles {
            let topLane = obstacle.y - clearance
            let bottomLane = obstacle.y + obstacle.height + clearance
            let leftLane = obstacle.x - clearance
            let rightLane = obstacle.x + obstacle.width + clearance

            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: sourceLead.x, y: topLane), CanvasEdgePoint(x: targetLead.x, y: topLane), targetLead]))
            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: sourceLead.x, y: bottomLane), CanvasEdgePoint(x: targetLead.x, y: bottomLane), targetLead]))
            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: leftLane, y: sourceLead.y), CanvasEdgePoint(x: leftLane, y: targetLead.y), targetLead]))
            candidates.append(simplified([sourceLead, CanvasEdgePoint(x: rightLane, y: sourceLead.y), CanvasEdgePoint(x: rightLane, y: targetLead.y), targetLead]))
        }

        let clearCandidates = candidates.filter { candidate in
            !polylineIntersectsObstacles([start] + candidate + [end], obstacles: obstacles, clearance: clearance)
        }
        let candidatesToScore = clearCandidates.isEmpty ? candidates : clearCandidates

        return candidatesToScore
            .min { score([start] + $0 + [end]) < score([start] + $1 + [end]) } ?? []
    }

    public static func polylineIntersectsObstacles(
        _ points: [CanvasEdgePoint],
        obstacles: [CanvasFrameRect],
        clearance: Double = 0
    ) -> Bool {
        guard points.count >= 2, !obstacles.isEmpty else { return false }
        let expandedObstacles = obstacles.map { expanded($0, by: clearance) }
        for index in points.indices.dropLast() {
            let start = points[index]
            let end = points[index + 1]
            if expandedObstacles.contains(where: { segmentIntersectsRect(start, end, $0) }) {
                return true
            }
        }
        return false
    }

    private static func offset(_ point: CanvasEdgePoint, direction: CanvasEdgePoint, distance: Double) -> CanvasEdgePoint {
        let vector = normalized(direction, fallback: CanvasEdgePoint(x: 1, y: 0))
        return CanvasEdgePoint(x: point.x + vector.x * distance, y: point.y + vector.y * distance)
    }

    private static func safeLead(
        from point: CanvasEdgePoint,
        direction: CanvasEdgePoint,
        distance: Double,
        avoiding obstacles: [CanvasFrameRect]
    ) -> CanvasEdgePoint {
        let lead = offset(point, direction: direction, distance: distance)
        return obstacles.contains(where: { contains(lead, in: $0) }) ? point : lead
    }

    private static func expanded(_ rect: CanvasFrameRect, by clearance: Double) -> CanvasFrameRect {
        CanvasFrameRect(
            id: rect.id,
            x: rect.x - clearance,
            y: rect.y - clearance,
            width: rect.width + clearance * 2,
            height: rect.height + clearance * 2
        )
    }

    private static func segmentIntersectsRect(_ start: CanvasEdgePoint, _ end: CanvasEdgePoint, _ rect: CanvasFrameRect) -> Bool {
        if contains(start, in: rect) || contains(end, in: rect) {
            return true
        }

        let topLeft = CanvasEdgePoint(x: rect.x, y: rect.y)
        let topRight = CanvasEdgePoint(x: rect.x + rect.width, y: rect.y)
        let bottomLeft = CanvasEdgePoint(x: rect.x, y: rect.y + rect.height)
        let bottomRight = CanvasEdgePoint(x: rect.x + rect.width, y: rect.y + rect.height)

        return segmentsIntersect(start, end, topLeft, topRight) ||
            segmentsIntersect(start, end, topRight, bottomRight) ||
            segmentsIntersect(start, end, bottomRight, bottomLeft) ||
            segmentsIntersect(start, end, bottomLeft, topLeft)
    }

    private static func contains(_ point: CanvasEdgePoint, in rect: CanvasFrameRect) -> Bool {
        point.x >= rect.x &&
            point.x <= rect.x + rect.width &&
            point.y >= rect.y &&
            point.y <= rect.y + rect.height
    }

    private static func segmentsIntersect(
        _ a: CanvasEdgePoint,
        _ b: CanvasEdgePoint,
        _ c: CanvasEdgePoint,
        _ d: CanvasEdgePoint
    ) -> Bool {
        let d1 = direction(c, d, a)
        let d2 = direction(c, d, b)
        let d3 = direction(a, b, c)
        let d4 = direction(a, b, d)

        if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
            ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
            return true
        }

        return approximatelyZero(d1) && onSegment(c, d, a) ||
            approximatelyZero(d2) && onSegment(c, d, b) ||
            approximatelyZero(d3) && onSegment(a, b, c) ||
            approximatelyZero(d4) && onSegment(a, b, d)
    }

    private static func direction(_ a: CanvasEdgePoint, _ b: CanvasEdgePoint, _ c: CanvasEdgePoint) -> Double {
        (c.x - a.x) * (b.y - a.y) - (b.x - a.x) * (c.y - a.y)
    }

    private static func onSegment(_ a: CanvasEdgePoint, _ b: CanvasEdgePoint, _ c: CanvasEdgePoint) -> Bool {
        c.x >= min(a.x, b.x) - 0.0001 &&
            c.x <= max(a.x, b.x) + 0.0001 &&
            c.y >= min(a.y, b.y) - 0.0001 &&
            c.y <= max(a.y, b.y) + 0.0001
    }

    private static func approximatelyZero(_ value: Double) -> Bool {
        abs(value) < 0.0001
    }

    private static func simplified(_ points: [CanvasEdgePoint]) -> [CanvasEdgePoint] {
        var output: [CanvasEdgePoint] = []
        for point in points {
            if let last = output.last,
               distance(last, point) < 1 {
                continue
            }
            output.append(point)
        }
        return removeCollinear(output)
    }

    private static func removeCollinear(_ points: [CanvasEdgePoint]) -> [CanvasEdgePoint] {
        guard points.count >= 3 else { return points }
        var output: [CanvasEdgePoint] = []
        for point in points {
            output.append(point)
            while output.count >= 3 {
                let count = output.count
                let a = output[count - 3]
                let b = output[count - 2]
                let c = output[count - 1]
                let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
                if abs(cross) < 0.0001 {
                    output.remove(at: count - 2)
                } else {
                    break
                }
            }
        }
        return output
    }

    private static func score(_ points: [CanvasEdgePoint]) -> Double {
        guard points.count >= 2 else { return .greatestFiniteMagnitude }
        var total = 0.0
        for index in points.indices.dropLast() {
            total += distance(points[index], points[index + 1])
        }
        return total + Double(max(0, points.count - 2)) * 18
    }

    private static func vector(from start: CanvasEdgePoint, to end: CanvasEdgePoint) -> CanvasEdgePoint {
        CanvasEdgePoint(x: end.x - start.x, y: end.y - start.y)
    }

    private static func distance(_ lhs: CanvasEdgePoint, _ rhs: CanvasEdgePoint) -> Double {
        let dx = rhs.x - lhs.x
        let dy = rhs.y - lhs.y
        return sqrt(dx * dx + dy * dy)
    }

    private static func normalized(_ vector: CanvasEdgePoint, fallback: CanvasEdgePoint) -> CanvasEdgePoint {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y)
        if length > 0.0001 {
            return CanvasEdgePoint(x: vector.x / length, y: vector.y / length)
        }

        let fallbackLength = sqrt(fallback.x * fallback.x + fallback.y * fallback.y)
        if fallbackLength > 0.0001 {
            return CanvasEdgePoint(x: fallback.x / fallbackLength, y: fallback.y / fallbackLength)
        }

        return CanvasEdgePoint(x: 1, y: 0)
    }
}

public enum CanvasViewportProjection {
    public static func screenPoint(
        x: Double,
        y: Double,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasEdgePoint {
        CanvasEdgePoint(
            x: x * zoom + viewportX,
            y: y * zoom + viewportY
        )
    }

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

    public static func canvasPoint(
        screenX: Double,
        screenY: Double,
        zoom: Double,
        viewportX: Double,
        viewportY: Double
    ) -> CanvasEdgePoint {
        let safeZoom = max(zoom, 0.01)
        return CanvasEdgePoint(
            x: (screenX - viewportX) / safeZoom,
            y: (screenY - viewportY) / safeZoom
        )
    }
}

public enum CanvasEdgeControlHandleMetrics {
    public static func diameter(zoom: Double, baseDiameter: Double) -> Double {
        baseDiameter * max(zoom, 0.01)
    }
}

public enum CanvasResizeHandleGeometry {
    public static let baseVisualSize = 22.0
    public static let basePadding = 6.0

    public static var baseInset: Double {
        basePadding + baseVisualSize / 2
    }

    public static var baseHitSize: Double {
        baseVisualSize + basePadding * 2
    }

    public static func center(in rect: CanvasFrameRect, zoom: Double) -> CanvasEdgePoint {
        let scale = max(zoom, 0.01)
        let inset = baseInset * scale
        return CanvasEdgePoint(
            x: rect.x + rect.width - inset,
            y: rect.y + rect.height - inset
        )
    }

    public static func hitRect(center: CanvasEdgePoint, zoom: Double) -> CanvasFrameRect {
        let size = baseHitSize * max(zoom, 0.01)
        return CanvasFrameRect(
            id: "resize-handle",
            x: center.x - size / 2,
            y: center.y - size / 2,
            width: size,
            height: size
        )
    }

    public static func contains(_ point: CanvasEdgePoint, in rect: CanvasFrameRect) -> Bool {
        point.x >= rect.x &&
            point.x <= rect.x + rect.width &&
            point.y >= rect.y &&
            point.y <= rect.y + rect.height
    }
}

public enum CanvasInteractionMetrics {
    public static let nodeHitSlop = 8.0
}

public enum CanvasIconButtonMetrics {
    public static let circleDiameter = 22.0
    public static let symbolDiameter = 13.0

    public static var symbolOrigin: Double {
        (circleDiameter - symbolDiameter) / 2
    }
}

public enum CanvasEdgeStyleOptions {
    private static let controlPointLockedToken = "controlPointLocked"
    private static let separator = ";"

    public static func isControlPointLocked(_ style: String) -> Bool {
        tokens(in: style).contains(controlPointLockedToken)
    }

    public static func style(_ style: String, controlPointLocked: Bool) -> String {
        var values = tokens(in: style)
        if controlPointLocked {
            values.insert(controlPointLockedToken)
        } else {
            values.remove(controlPointLockedToken)
        }
        if values.isEmpty {
            return "default"
        }
        return values.sorted().joined(separator: separator)
    }

    private static func tokens(in style: String) -> Set<String> {
        let parts = style
            .split(separator: Character(separator))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "default" }
        return Set(parts)
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

public enum CanvasHitTarget: Equatable, Sendable {
    case node(String)
    case background
}

public enum CanvasHitTesting {
    public static func target(
        at point: CanvasEdgePoint,
        nodes: [CanvasFrameRect],
        hitSlop: Double = 0
    ) -> CanvasHitTarget {
        for node in nodes.reversed() where contains(point, in: node, hitSlop: hitSlop) {
            return .node(node.id)
        }
        return .background
    }

    public static func contains(_ point: CanvasEdgePoint, in rect: CanvasFrameRect, hitSlop: Double = 0) -> Bool {
        point.x >= rect.x - hitSlop &&
            point.y >= rect.y - hitSlop &&
            point.x <= rect.x + rect.width + hitSlop &&
            point.y <= rect.y + rect.height + hitSlop
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

    public static func movedControlPoints(
        _ points: [CanvasFramePosition],
        inside frame: CanvasFrameRect,
        deltaX: Double,
        deltaY: Double
    ) -> [CanvasFramePosition] {
        points.map { point in
            guard contains(point, in: frame) else {
                return point
            }
            return CanvasFramePosition(id: point.id, x: point.x + deltaX, y: point.y + deltaY)
        }
    }

    public static func contains(_ point: CanvasFramePosition, in frame: CanvasFrameRect) -> Bool {
        point.x >= frame.x &&
            point.y >= frame.y &&
            point.x <= frame.x + frame.width &&
            point.y <= frame.y + frame.height
    }

    public static func movedRects(
        _ rects: [CanvasFrameRect],
        movedIDs: Set<String>,
        deltaX: Double,
        deltaY: Double
    ) -> [CanvasFrameRect] {
        rects.map { rect in
            guard movedIDs.contains(rect.id) else { return rect }
            return CanvasFrameRect(
                id: rect.id,
                x: rect.x + deltaX,
                y: rect.y + deltaY,
                width: rect.width,
                height: rect.height
            )
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

public enum AppPreferenceKeys {
    public static let canvasScrollZoomDirection = "canvasScrollZoomDirection"
    public static let canvasDefaultZoomPercent = "canvasDefaultZoomPercent"
}

public enum CanvasScrollZoomDirection: String, CaseIterable, Identifiable, Sendable {
    case scrollDownZoomsOut
    case scrollDownZoomsIn

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scrollDownZoomsOut:
            "向下滚动缩小（当前）"
        case .scrollDownZoomsIn:
            "向下滚动放大"
        }
    }

    public static func resolved(_ rawValue: String) -> CanvasScrollZoomDirection {
        CanvasScrollZoomDirection(rawValue: rawValue) ?? .scrollDownZoomsOut
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

    public static func zoom(
        forScrollDeltaY deltaY: Double,
        current: Double,
        minimum: Double,
        maximum: Double,
        direction: CanvasScrollZoomDirection = .scrollDownZoomsOut
    ) -> Double {
        let signedDelta = direction == .scrollDownZoomsOut ? -deltaY : deltaY
        let multiplier = pow(1.0025, signedDelta)
        return clamped(current * multiplier, minimum: minimum, maximum: maximum)
    }

    public static func viewport(
        keepingScreenX screenX: Double,
        screenY: Double,
        canvasX: Double,
        canvasY: Double,
        zoom: Double
    ) -> (x: Double, y: Double) {
        (
            x: screenX - canvasX * zoom,
            y: screenY - canvasY * zoom
        )
    }
}

public enum CanvasZoomBaseline {
    public static let standardBaseline = 0.35
    public static let minimumZoom = 0.12
    public static let maximumZoom = 2.4
    public static let defaultPercent = 100.0

    public static func actualZoom(
        percent: Double,
        standardBaseline: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        let safePercent = min(max(percent, 25), 500)
        return CanvasZoomScale.clamped(
            standardBaseline * safePercent / 100,
            minimum: minimum,
            maximum: maximum
        )
    }
}
