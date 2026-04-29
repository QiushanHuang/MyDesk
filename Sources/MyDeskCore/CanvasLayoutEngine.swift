import Foundation

public struct CanvasLayoutNode: Codable, Equatable, Identifiable, Sendable {
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

public enum CanvasLayoutEngine {
    public static func autoArrange(
        _ nodes: [CanvasLayoutNode],
        columns: Int = 3,
        spacing: Double = 48
    ) -> [CanvasLayoutNode] {
        let safeColumns = max(columns, 1)
        return nodes.enumerated().map { index, node in
            var arranged = node
            let column = index % safeColumns
            let row = index / safeColumns
            arranged.x = Double(column) * (node.width + spacing)
            arranged.y = Double(row) * (node.height + spacing)
            return arranged
        }
    }

    public static func alignLeft(_ nodes: [CanvasLayoutNode]) -> [CanvasLayoutNode] {
        guard let minX = nodes.map(\.x).min() else { return nodes }
        return nodes.map { node in
            var aligned = node
            aligned.x = minX
            return aligned
        }
    }

    public static func alignTop(_ nodes: [CanvasLayoutNode]) -> [CanvasLayoutNode] {
        guard let minY = nodes.map(\.y).min() else { return nodes }
        return nodes.map { node in
            var aligned = node
            aligned.y = minY
            return aligned
        }
    }
}
