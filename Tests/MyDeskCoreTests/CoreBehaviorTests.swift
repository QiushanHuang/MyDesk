import XCTest
@testable import MyDeskCore

final class CoreBehaviorTests: XCTestCase {
    func testShellQuoterHandlesSpacesAndSingleQuotes() {
        XCTAssertEqual(ShellQuoter.singleQuote("/tmp/My Folder"), "'/tmp/My Folder'")
        XCTAssertEqual(ShellQuoter.singleQuote("/tmp/Joshua's Work"), "'/tmp/Joshua'\\''s Work'")
    }

    func testAppleScriptStringEscapesQuotesAndBackslashes() {
        XCTAssertEqual(ShellQuoter.appleScriptString("say \"hi\" \\"), "\"say \\\"hi\\\" \\\\\"")
    }

    func testTerminalCommandStopsWhenCdFails() {
        XCTAssertEqual(
            ShellQuoter.terminalCommand(command: "rm -rf build", workingDirectory: "/tmp/Missing Folder"),
            "cd '/tmp/Missing Folder' && rm -rf build"
        )
    }

    func testCanvasAutoArrangeProducesGridPositions() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "c", x: 0, y: 0, width: 120, height: 80)
        ]
        let arranged = CanvasLayoutEngine.autoArrange(nodes, columns: 2, spacing: 40)
        XCTAssertEqual(arranged[0].x, 0)
        XCTAssertEqual(arranged[1].x, 160)
        XCTAssertEqual(arranged[2].y, 120)
    }

    func testAlignLeftUsesMinimumX() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 50, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 10, y: 20, width: 120, height: 80)
        ]
        let aligned = CanvasLayoutEngine.alignLeft(nodes)
        XCTAssertEqual(aligned.map(\.x), [10, 10])
    }

    func testWorkspaceSidebarOrderingPinsFirstThenUsesStableSort() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let records = [
            WorkspaceSidebarOrderRecord(id: "recent", isPinned: false, sortIndex: 0, updatedAt: newer),
            WorkspaceSidebarOrderRecord(id: "pinned-later", isPinned: true, sortIndex: 20, updatedAt: older),
            WorkspaceSidebarOrderRecord(id: "pinned-earlier", isPinned: true, sortIndex: 10, updatedAt: newer),
            WorkspaceSidebarOrderRecord(id: "old", isPinned: false, sortIndex: 0, updatedAt: older)
        ]

        XCTAssertEqual(
            WorkspaceSidebarOrdering.ordered(records).map(\.id),
            ["pinned-earlier", "pinned-later", "recent", "old"]
        )
    }

    func testWorkspaceSidebarOrderingMovesItemsWithinCurrentOrder() {
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], moving: "b", direction: .up),
            ["b", "a", "c"]
        )
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], moving: "b", direction: .down),
            ["a", "c", "b"]
        )
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], moving: "missing", direction: .up),
            ["a", "b", "c"]
        )
    }

    func testManifestRoundTripKeepsSchemaVersion() throws {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Map", viewportX: 12, viewportY: -8, zoom: 1.4)
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "Body", nodeType: "note", objectType: nil, objectId: nil, x: 1, y: 2, width: 180, height: 96, collapsed: true)
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: "relates", style: "dashed")
            ],
            aliases: []
        )
        let data = try JSONEncoder.mydesk.encode(manifest)
        let decoded = try JSONDecoder.mydesk.decode(ExportManifest.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.canvases.first?.viewportX, 12)
        XCTAssertEqual(decoded.canvases.first?.viewportY, -8)
        XCTAssertEqual(decoded.canvases.first?.zoom, 1.4)
        XCTAssertEqual(decoded.nodes.first?.collapsed, true)
        XCTAssertEqual(decoded.edges.first?.style, "dashed")
    }

    func testLegacyManifestDefaultsNewCanvasFields() throws {
        let json = """
        {
          "aliases": [],
          "canvases": [
            { "id": "canvas", "workspaceId": "workspace", "title": "Map" }
          ],
          "edges": [
            { "id": "edge", "canvasId": "canvas", "sourceNodeId": "node", "targetNodeId": "node", "label": "" }
          ],
          "exportedAt": "1970-01-01T00:00:00Z",
          "nodes": [
            { "id": "node", "canvasId": "canvas", "title": "Node", "body": "", "nodeType": "note", "x": 1, "y": 2, "width": 180, "height": 96 }
          ],
          "resources": [
            { "id": "resource", "workspaceId": null, "title": "Projects", "targetType": "folder", "displayPath": "/tmp/Projects", "lastResolvedPath": "/tmp/Projects", "note": "", "tags": [], "scope": "global", "status": "available" }
          ],
          "schemaVersion": 1,
          "snippets": [],
          "workspaces": []
        }
        """

        let decoded = try JSONDecoder.mydesk.decode(ExportManifest.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.canvases.first?.viewportX, 0)
        XCTAssertEqual(decoded.canvases.first?.viewportY, 0)
        XCTAssertEqual(decoded.canvases.first?.zoom, 1)
        XCTAssertEqual(decoded.nodes.first?.collapsed, false)
        XCTAssertEqual(decoded.edges.first?.style, "default")
        XCTAssertEqual(decoded.resources.first?.isPinned, true)
        XCTAssertEqual(decoded.resources.first?.originalName, "")
        XCTAssertEqual(decoded.canvases.first?.linkAnimationTheme, "blue")
        XCTAssertEqual(decoded.canvases.first?.animationsEnabled, true)
        XCTAssertEqual(decoded.nodes.first?.zIndex, 0)
        XCTAssertEqual(decoded.edges.first?.targetArrow, "arrow")
    }

    func testResourceLibraryFilteringKeepsGlobalSourcesSeparateFromPinnedShortcuts() {
        let records = [
            ResourceLibraryRecord(id: "folder-source", targetType: "folder", title: "Projects", originalName: "Projects", customName: "", displayPath: "/Users/me/Projects", isPinned: false, updatedAt: Date(timeIntervalSince1970: 10), sortIndex: 0),
            ResourceLibraryRecord(id: "folder-pin", targetType: "folder", title: "Archive", originalName: "Archive", customName: "", displayPath: "/Users/me/Archive", isPinned: true, updatedAt: Date(timeIntervalSince1970: 20), sortIndex: 0),
            ResourceLibraryRecord(id: "file-pin", targetType: "file", title: "Plan.md", originalName: "Plan.md", customName: "Launch Plan", displayPath: "/Users/me/Plan.md", isPinned: true, updatedAt: Date(timeIntervalSince1970: 30), sortIndex: 0)
        ]

        XCTAssertEqual(ResourceLibraryFiltering.folders(in: records).map(\.id), ["folder-pin", "folder-source"])
        XCTAssertEqual(ResourceLibraryFiltering.files(in: records).map(\.id), ["file-pin"])
        XCTAssertEqual(ResourceLibraryFiltering.pinnedFolders(in: records).map(\.id), ["folder-pin"])
        XCTAssertEqual(ResourceLibraryFiltering.pinnedFiles(in: records).map(\.id), ["file-pin"])
    }

    func testResourceDisplayNameShowsOriginalNameThenCustomName() {
        XCTAssertEqual(
            ResourceLibraryRecord(id: "a", targetType: "file", title: "Fallback", originalName: "Invoice.pdf", customName: "Client Copy", displayPath: "/tmp/Invoice.pdf", isPinned: false).displayName,
            "Invoice.pdf · Client Copy"
        )
        XCTAssertEqual(
            ResourceLibraryRecord(id: "b", targetType: "folder", title: "Fallback", originalName: "", customName: "", displayPath: "/tmp/Research", isPinned: false).displayName,
            "Fallback"
        )
    }

    func testCanvasEdgeIdentityTreatsOppositeDirectionsAsDifferentLinks() {
        let existing = [
            CanvasEdgeIdentity(sourceNodeId: "a", targetNodeId: "b")
        ]

        XCTAssertTrue(CanvasEdgeIdentity.exists(sourceNodeId: "a", targetNodeId: "b", in: existing))
        XCTAssertFalse(CanvasEdgeIdentity.exists(sourceNodeId: "b", targetNodeId: "a", in: existing))
    }

    func testFinderRoutingRevealsFilesButOpensFolders() {
        XCTAssertEqual(ResourceFinderRouting.doubleClickAction(forTargetType: "folder"), .open)
        XCTAssertEqual(ResourceFinderRouting.doubleClickAction(forTargetType: "file"), .reveal)
    }

    func testFrameGeometryFindsFullyContainedChildrenOnly() {
        let frame = CanvasFrameRect(id: "frame", x: 0, y: 0, width: 300, height: 220)
        let candidates = [
            CanvasFrameRect(id: "inside", x: 40, y: 50, width: 120, height: 80),
            CanvasFrameRect(id: "overlap", x: 250, y: 50, width: 120, height: 80),
            CanvasFrameRect(id: "outside", x: 320, y: 50, width: 80, height: 80)
        ]

        XCTAssertEqual(CanvasFrameGeometry.childNodeIDs(inside: frame, candidates: candidates), ["inside"])
    }

    func testFrameGeometryMovesFrameAndChildrenBySameDelta() {
        let positions = [
            CanvasFramePosition(id: "frame", x: 0, y: 0),
            CanvasFramePosition(id: "child-a", x: 40, y: 50),
            CanvasFramePosition(id: "child-b", x: 100, y: 120),
            CanvasFramePosition(id: "outside", x: 400, y: 120)
        ]

        let moved = CanvasFrameGeometry.movedPositions(
            positions,
            movingFrameId: "frame",
            childNodeIDs: ["child-a", "child-b"],
            deltaX: 24,
            deltaY: -16
        )

        XCTAssertEqual(moved.first { $0.id == "frame" }?.x, 24)
        XCTAssertEqual(moved.first { $0.id == "frame" }?.y, -16)
        XCTAssertEqual(moved.first { $0.id == "child-a" }?.x, 64)
        XCTAssertEqual(moved.first { $0.id == "child-a" }?.y, 34)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.x, 400)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.y, 120)
    }

    func testCanvasEdgeAnchoringUsesHorizontalEdgeMidpoints() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 20, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 60, width: 120, height: 90)

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target)

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 100, y: 60))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 240, y: 105))
    }

    func testCanvasEdgeAnchoringUsesVerticalEdgeMidpoints() {
        let source = CanvasFrameRect(id: "top", x: 20, y: 0, width: 120, height: 80)
        let target = CanvasFrameRect(id: "bottom", x: 60, y: 240, width: 100, height: 70)

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target)

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 80, y: 80))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 110, y: 240))
    }

    func testCanvasEdgeAnchoringCanStopBeforeTargetBorderForVisibleArrowheads() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 0, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 0, width: 120, height: 80)

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target, targetClearance: 14)

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 100, y: 40))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 226, y: 40))
    }

    func testCanvasViewportProjectionUsesScaledVisibleBounds() {
        let rect = CanvasViewportProjection.screenRect(
            id: "node",
            x: 100,
            y: 40,
            width: 214,
            height: 132,
            offsetX: 12,
            offsetY: -4,
            zoom: 0.5425,
            viewportX: 20,
            viewportY: 30
        )

        XCTAssertEqual(rect.x, 80.76, accuracy: 0.0001)
        XCTAssertEqual(rect.y, 49.53, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 116.095, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 71.61, accuracy: 0.0001)
    }

    func testProjectedEdgeAnchorsLandOnTargetVisibleBorder() {
        let source = CanvasViewportProjection.screenRect(
            id: "source",
            x: 100,
            y: 80,
            width: 214,
            height: 132,
            zoom: 0.5425,
            viewportX: 20,
            viewportY: 30
        )
        let target = CanvasViewportProjection.screenRect(
            id: "target",
            x: 460,
            y: 120,
            width: 214,
            height: 132,
            zoom: 0.5425,
            viewportX: 20,
            viewportY: 30
        )

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target)

        XCTAssertEqual(anchors.start.x, source.x + source.width, accuracy: 0.0001)
        XCTAssertEqual(anchors.end.x, target.x, accuracy: 0.0001)
    }

    func testCanvasViewportProjectionConvertsScreenPointBackToCanvasPoint() {
        let point = CanvasViewportProjection.canvasPoint(
            screenX: 220,
            screenY: 146,
            zoom: 0.5,
            viewportX: 20,
            viewportY: -4
        )

        XCTAssertEqual(point.x, 400, accuracy: 0.0001)
        XCTAssertEqual(point.y, 300, accuracy: 0.0001)
    }

    func testCanvasEdgeRecordKeepsCustomControlPoint() throws {
        let edge = CanvasEdgeRecord(
            id: "edge",
            canvasId: "canvas",
            sourceNodeId: "source",
            targetNodeId: "target",
            label: "",
            controlPointX: 320,
            controlPointY: 180
        )

        let encoded = try JSONEncoder().encode(edge)
        let decoded = try JSONDecoder().decode(CanvasEdgeRecord.self, from: encoded)

        XCTAssertEqual(decoded.controlPointX, 320)
        XCTAssertEqual(decoded.controlPointY, 180)
    }

    func testCanvasEdgeFlowPhaseWrapsWithoutStatefulAnimation() {
        XCTAssertEqual(CanvasEdgeFlowPhase.dashPhase(elapsed: 0, duration: 2, cycleLength: 180), 0)
        XCTAssertEqual(CanvasEdgeFlowPhase.dashPhase(elapsed: 1, duration: 2, cycleLength: 180), -90)
        XCTAssertEqual(CanvasEdgeFlowPhase.dashPhase(elapsed: 2.5, duration: 2, cycleLength: 180), -45)
    }

    func testFrameGeometryResizingClampsToMinimumSize() {
        let frame = CanvasFrameRect(id: "frame", x: 0, y: 0, width: 300, height: 220)

        let resized = CanvasFrameGeometry.resizedFrame(frame, deltaWidth: -200, deltaHeight: -120, minimumWidth: 240, minimumHeight: 160)

        XCTAssertEqual(resized.x, 0)
        XCTAssertEqual(resized.y, 0)
        XCTAssertEqual(resized.width, 240)
        XCTAssertEqual(resized.height, 160)
    }

    func testFrameGeometryChoosesSmallestContainingFrame() {
        let card = CanvasFrameRect(id: "card", x: 80, y: 80, width: 100, height: 80)
        let frames = [
            CanvasFrameRect(id: "outer", x: 0, y: 0, width: 400, height: 300),
            CanvasFrameRect(id: "inner", x: 60, y: 60, width: 180, height: 140)
        ]

        XCTAssertEqual(CanvasFrameGeometry.containingFrameId(for: card, frames: frames), "inner")
    }

    func testCanvasDropPlacementCentersCardAtDropLocation() {
        let placement = CanvasDropPlacement.cardOrigin(
            dropX: 260,
            dropY: 180,
            viewportX: 40,
            viewportY: -20,
            zoom: 2,
            cardWidth: 120,
            cardHeight: 80
        )

        XCTAssertEqual(placement.x, 50)
        XCTAssertEqual(placement.y, 60)
    }

    func testCanvasZoomScaleLabelsBaselineZoomAsOneHundredPercent() {
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: 0.35, baseline: 0.35), 100)
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: 0.175, baseline: 0.35), 50)
    }

    func testCanvasZoomScaleAllowsZoomBelowBaseline() {
        XCTAssertEqual(CanvasZoomScale.clamped(0.10, minimum: 0.12, maximum: 2.4), 0.12)
        XCTAssertEqual(CanvasZoomScale.zoom(forDisplayScale: 1, baseline: 0.35, minimum: 0.12, maximum: 2.4), 0.35)
        XCTAssertEqual(CanvasZoomScale.zoom(forDisplayScale: 0.5, baseline: 0.35, minimum: 0.12, maximum: 2.4), 0.175)
    }

    func testFolderPreviewOrderingPutsFoldersFirstThenNames() {
        let items = [
            FolderPreviewItemRecord(id: "file-b", name: "Beta.txt", isDirectory: false),
            FolderPreviewItemRecord(id: "folder-z", name: "Zeta", isDirectory: true),
            FolderPreviewItemRecord(id: "folder-a", name: "Archive", isDirectory: true),
            FolderPreviewItemRecord(id: "file-a", name: "alpha.md", isDirectory: false)
        ]

        XCTAssertEqual(
            FolderPreviewOrdering.ordered(items).map(\.id),
            ["folder-a", "folder-z", "file-a", "file-b"]
        )
    }

    func testCanvasEdgeAnimationPolicyOnlyAnimatesBlueEnabledEdgesAtSmallScale() {
        XCTAssertTrue(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: false, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "off", animationsEnabled: true, reduceMotion: false, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: false, reduceMotion: false, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: true, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: false, edgeCount: 180))
    }
}
