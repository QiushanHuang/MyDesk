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

    func testPersistentStoreLayoutUsesAppSpecificStoreDirectory() {
        let support = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)
        let layout = MyDeskStoreLayout(applicationSupportDirectory: support)

        XCTAssertEqual(
            layout.storeURL.path,
            "/tmp/Application Support/studio.qiushan.mydesk/Stores/MyDesk.store"
        )
        XCTAssertEqual(layout.legacyDefaultStoreURL.path, "/tmp/Application Support/default.store")
        XCTAssertEqual(
            layout.backupDirectory.path,
            "/tmp/Application Support/studio.qiushan.mydesk/Backups"
        )
    }

    func testPersistentStoreLayoutTreatsSQLiteCompanionsAsOneStore() {
        let store = URL(fileURLWithPath: "/tmp/MyDesk.store")

        XCTAssertEqual(
            MyDeskStoreLayout.sqliteFileSet(for: store).map(\.lastPathComponent),
            ["MyDesk.store", "MyDesk.store-wal", "MyDesk.store-shm"]
        )
    }

    func testPersistentStoreBackupRetentionDeletesOldestFoldersFirst() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = [
            backupRoot.appendingPathComponent("20260430-091100", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091300", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091200", isDirectory: true),
            backupRoot.appendingPathComponent("not-a-backup", isDirectory: true)
        ]

        XCTAssertEqual(
            MyDeskStoreLayout.backupFoldersToPrune(folders, keepingNewest: 2).map(\.lastPathComponent),
            ["20260430-091100"]
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

    func testCanvasAutoArrangeGridUsesColumnWidthsToAvoidOverlap() {
        let nodes = [
            CanvasLayoutNode(id: "wide", x: 0, y: 0, width: 360, height: 80),
            CanvasLayoutNode(id: "right", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "bottom", x: 0, y: 0, width: 180, height: 80)
        ]

        let arranged = CanvasLayoutEngine.autoArrange(nodes, columns: 2, spacing: 40)

        XCTAssertEqual(arranged[1].x, 400)
        XCTAssertFalse(layoutNodesOverlap(arranged))
    }

    func testCanvasAutoArrangeUsesEdgesForLeftToRightWorkflowLayers() {
        let nodes = [
            CanvasLayoutNode(id: "finish", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "source", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "branch", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "middle", x: 0, y: 0, width: 120, height: 80)
        ]
        let edges = [
            CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "middle"),
            CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "branch"),
            CanvasLayoutEdge(sourceNodeId: "middle", targetNodeId: "finish")
        ]

        let arranged = Dictionary(
            uniqueKeysWithValues: CanvasLayoutEngine.autoArrange(
                nodes,
                edges: edges,
                horizontalSpacing: 80,
                verticalSpacing: 40
            ).map { ($0.id, $0) }
        )

        XCTAssertLessThan(arranged["source"]!.x, arranged["middle"]!.x)
        XCTAssertLessThan(arranged["source"]!.x, arranged["branch"]!.x)
        XCTAssertLessThan(arranged["middle"]!.x, arranged["finish"]!.x)
        XCTAssertEqual(arranged["middle"]!.x, arranged["branch"]!.x)
        XCTAssertLessThan(arranged["middle"]!.y, arranged["branch"]!.y)
    }

    func testCanvasAutoArrangePlacesDisconnectedNodesAfterWorkflowWithoutOverlap() {
        let nodes = [
            CanvasLayoutNode(id: "source", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "target", x: 0, y: 0, width: 140, height: 90),
            CanvasLayoutNode(id: "loose-a", x: 0, y: 0, width: 180, height: 110),
            CanvasLayoutNode(id: "loose-b", x: 0, y: 0, width: 120, height: 80)
        ]
        let edges = [
            CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "target")
        ]

        let arranged = CanvasLayoutEngine.autoArrange(
            nodes,
            edges: edges,
            horizontalSpacing: 80,
            verticalSpacing: 40
        )
        let byId = Dictionary(uniqueKeysWithValues: arranged.map { ($0.id, $0) })
        let workflowBottom = max(byId["source"]!.y + byId["source"]!.height, byId["target"]!.y + byId["target"]!.height)

        XCTAssertGreaterThan(byId["loose-a"]!.y, workflowBottom)
        XCTAssertGreaterThan(byId["loose-b"]!.y, workflowBottom)
        XCTAssertFalse(layoutNodesOverlap(arranged))
    }

    func testAlignLeftUsesMinimumX() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 50, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 10, y: 20, width: 120, height: 80)
        ]
        let aligned = CanvasLayoutEngine.alignLeft(nodes)
        XCTAssertEqual(aligned.map(\.x), [10, 10])
    }

    private func layoutNodesOverlap(_ nodes: [CanvasLayoutNode]) -> Bool {
        for lhsIndex in nodes.indices {
            for rhsIndex in nodes.indices where rhsIndex > lhsIndex {
                let lhs = nodes[lhsIndex]
                let rhs = nodes[rhsIndex]
                let separated = lhs.x + lhs.width <= rhs.x ||
                    rhs.x + rhs.width <= lhs.x ||
                    lhs.y + lhs.height <= rhs.y ||
                    rhs.y + rhs.height <= lhs.y
                if !separated {
                    return true
                }
            }
        }
        return false
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

    func testWorkbenchSidebarMetricsAreCompactButReadable() {
        XCTAssertLessThan(WorkbenchSidebarMetrics.idealWidth, 240)
        XCTAssertGreaterThanOrEqual(WorkbenchSidebarMetrics.minimumWidth, 200)
        XCTAssertGreaterThanOrEqual(WorkbenchSidebarMetrics.maximumWidth, WorkbenchSidebarMetrics.idealWidth)
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

    func testSnippetLibraryFilteringShowsGlobalAndCurrentWorkspaceOnly() {
        let global = SnippetLibraryRecord(id: "global", scope: "global", workspaceId: nil, title: "Global", updatedAt: Date(timeIntervalSince1970: 1))
        let current = SnippetLibraryRecord(id: "current", scope: "workspace", workspaceId: "workspace-a", title: "Current", updatedAt: Date(timeIntervalSince1970: 3))
        let other = SnippetLibraryRecord(id: "other", scope: "workspace", workspaceId: "workspace-b", title: "Other", updatedAt: Date(timeIntervalSince1970: 4))

        let visible = SnippetLibraryFiltering.visible(
            [global, current, other],
            scope: "workspace",
            workspaceId: "workspace-a"
        )

        XCTAssertEqual(visible.map(\.id), ["current", "global"])
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

    func testFrameGeometryMovesContainedEdgeControlPointsWithFrame() {
        let frame = CanvasFrameRect(id: "frame", x: 100, y: 80, width: 300, height: 220)
        let points = [
            CanvasFramePosition(id: "inside", x: 180, y: 140),
            CanvasFramePosition(id: "outside", x: 40, y: 140)
        ]

        let moved = CanvasFrameGeometry.movedControlPoints(
            points,
            inside: frame,
            deltaX: 32,
            deltaY: -12
        )

        XCTAssertEqual(moved.first { $0.id == "inside" }?.x, 212)
        XCTAssertEqual(moved.first { $0.id == "inside" }?.y, 128)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.x, 40)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.y, 140)
    }

    func testFrameGeometryResolvesContainmentFromMovedRects() throws {
        let rects = [
            CanvasFrameRect(id: "frame", x: 0, y: 0, width: 300, height: 220),
            CanvasFrameRect(id: "child", x: 40, y: 50, width: 120, height: 80),
            CanvasFrameRect(id: "other-frame", x: 500, y: 0, width: 300, height: 220)
        ]

        let movedRects = CanvasFrameGeometry.movedRects(
            rects,
            movedIDs: ["frame", "child"],
            deltaX: 500,
            deltaY: 0
        )
        let child = try XCTUnwrap(movedRects.first { $0.id == "child" })
        let frames = movedRects.filter { ["frame", "other-frame"].contains($0.id) }

        XCTAssertEqual(CanvasFrameGeometry.containingFrameId(for: child, frames: frames), "frame")
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

    func testCanvasEdgeAnchoringUsesControlPointDirectionForSourceWhenPresent() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 80, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 80, width: 120, height: 90)
        let control = CanvasEdgePoint(x: 50, y: 250)

        let anchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: target,
            control: control,
            targetClearance: 12
        )

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 50, y: 160))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 228, y: 125))
    }

    func testCanvasEdgeAnchoringUsesControlPointDirectionForTargetWhenPresent() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 80, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 80, width: 120, height: 90)
        let control = CanvasEdgePoint(x: 300, y: 0)

        let anchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: target,
            control: control,
            targetClearance: 12
        )

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 100, y: 120))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 300, y: 68))
    }

    func testCanvasEdgeAnchoringReportsInwardTargetDirectionForLeftAndTopEdges() {
        let source = CanvasFrameRect(id: "source", x: 0, y: 80, width: 100, height: 80)
        let leftTarget = CanvasFrameRect(id: "left-target", x: 240, y: 80, width: 120, height: 90)
        let topTarget = CanvasFrameRect(id: "top-target", x: 240, y: 80, width: 120, height: 90)

        let leftAnchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: leftTarget,
            control: CanvasEdgePoint(x: 40, y: 120)
        )
        let topAnchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: topTarget,
            control: CanvasEdgePoint(x: 300, y: 0)
        )

        XCTAssertEqual(leftAnchors.endDirection, CanvasEdgePoint(x: 1, y: 0))
        XCTAssertEqual(topAnchors.endDirection, CanvasEdgePoint(x: 0, y: 1))
    }

    func testCanvasEdgeCurveApproachesTargetFromOutsideLeftBorder() {
        let controls = CanvasEdgeCurveGeometry.automaticControls(
            start: CanvasEdgePoint(x: 100, y: 120),
            end: CanvasEdgePoint(x: 240, y: 125),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0)
        )

        XCTAssertGreaterThan(controls.control1.x, 100)
        XCTAssertLessThan(controls.control2.x, 240)
        XCTAssertEqual(
            CanvasEdgeCurveGeometry.terminalAngleRadians(endDirection: CanvasEdgePoint(x: 1, y: 0)),
            0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeCurveApproachesTargetFromOutsideTopBorder() {
        let controls = CanvasEdgeCurveGeometry.automaticControls(
            start: CanvasEdgePoint(x: 100, y: 120),
            end: CanvasEdgePoint(x: 300, y: 80),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 0, y: 1)
        )

        XCTAssertLessThan(controls.control2.y, 80)
        XCTAssertEqual(
            CanvasEdgeCurveGeometry.terminalAngleRadians(endDirection: CanvasEdgePoint(x: 0, y: 1)),
            Double.pi / 2,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeCurveKeepsContinuousTangentThroughControlPoint() {
        let segments = CanvasEdgeCurveGeometry.controlsThroughPoint(
            start: CanvasEdgePoint(x: 100, y: 120),
            control: CanvasEdgePoint(x: 190, y: 20),
            end: CanvasEdgePoint(x: 300, y: 80),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 0, y: 1)
        )

        let incomingTangent = CanvasEdgePoint(
            x: 190 - segments.first.control2.x,
            y: 20 - segments.first.control2.y
        )
        let outgoingTangent = CanvasEdgePoint(
            x: segments.second.control1.x - 190,
            y: segments.second.control1.y - 20
        )

        XCTAssertEqual(
            incomingTangent.x * outgoingTangent.y - incomingTangent.y * outgoingTangent.x,
            0,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(incomingTangent.x * outgoingTangent.x + incomingTangent.y * outgoingTangent.y, 0)
    }

    func testCanvasEdgeRoutePlannerReturnsNoRouteWhenDirectPathIsClear() {
        let route = CanvasEdgeRoutePlanner.routePoints(
            start: CanvasEdgePoint(x: 100, y: 40),
            end: CanvasEdgePoint(x: 320, y: 40),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [
                CanvasFrameRect(id: "clear", x: 160, y: 120, width: 100, height: 80)
            ],
            clearance: 24
        )

        XCTAssertTrue(route.isEmpty)
    }

    func testCanvasEdgeRoutePlannerRoutesAroundCardOnDirectPath() {
        let obstacle = CanvasFrameRect(id: "middle", x: 160, y: 0, width: 100, height: 90)
        let route = CanvasEdgeRoutePlanner.routePoints(
            start: CanvasEdgePoint(x: 100, y: 40),
            end: CanvasEdgePoint(x: 340, y: 40),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [obstacle],
            clearance: 24
        )
        let polyline = [CanvasEdgePoint(x: 100, y: 40)] + route + [CanvasEdgePoint(x: 340, y: 40)]

        XCTAssertFalse(route.isEmpty)
        XCTAssertFalse(CanvasEdgeRoutePlanner.polylineIntersectsObstacles(polyline, obstacles: [obstacle], clearance: 24))
    }

    func testCanvasEdgeRoutePlannerReroutesWhenMovedCardBecomesObstacle() {
        let start = CanvasEdgePoint(x: 100, y: 40)
        let end = CanvasEdgePoint(x: 340, y: 40)
        let clearObstacle = CanvasFrameRect(id: "middle", x: 160, y: 140, width: 100, height: 90)
        let blockingObstacle = CanvasFrameRect(id: "middle", x: 160, y: 0, width: 100, height: 90)

        let clearRoute = CanvasEdgeRoutePlanner.routePoints(
            start: start,
            end: end,
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [clearObstacle],
            clearance: 24
        )
        let blockingRoute = CanvasEdgeRoutePlanner.routePoints(
            start: start,
            end: end,
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [blockingObstacle],
            clearance: 24
        )

        XCTAssertTrue(clearRoute.isEmpty)
        XCTAssertFalse(blockingRoute.isEmpty)
    }

    func testCanvasEdgeRoutePlannerRoutesControlPointSegmentsAroundCard() {
        let start = CanvasEdgePoint(x: 100, y: 40)
        let control = CanvasEdgePoint(x: 220, y: 140)
        let end = CanvasEdgePoint(x: 340, y: 40)
        let obstacle = CanvasFrameRect(id: "middle", x: 170, y: 55, width: 100, height: 65)

        let route = CanvasEdgeRoutePlanner.routePoints(
            start: start,
            end: end,
            waypoints: [control],
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [obstacle],
            clearance: 18
        )
        let polyline = [start] + route + [end]

        XCTAssertTrue(route.contains(control))
        XCTAssertFalse(route.isEmpty)
        XCTAssertFalse(CanvasEdgeRoutePlanner.polylineIntersectsObstacles(polyline, obstacles: [obstacle], clearance: 18))
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

    func testCanvasHitTestingTreatsFullScaledCardRectAsNode() {
        let folder = CanvasFrameRect(id: "folder", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasHitTesting.target(
                at: CanvasEdgePoint(x: 158, y: 306),
                nodes: [folder]
            ),
            .node("folder")
        )
    }

    func testCanvasHitTestingFallsBackToBackgroundOutsideNodes() {
        let folder = CanvasFrameRect(id: "folder", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasHitTesting.target(
                at: CanvasEdgePoint(x: 149, y: 306),
                nodes: [folder]
            ),
            .background
        )
    }

    func testCanvasHitTestingUsesInteractionSlopAroundCardBorders() {
        let folder = CanvasFrameRect(id: "folder", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasHitTesting.target(
                at: CanvasEdgePoint(x: 158, y: 296),
                nodes: [folder],
                hitSlop: CanvasInteractionMetrics.nodeHitSlop
            ),
            .node("folder")
        )
    }

    func testCanvasIconButtonMetricsCenterSymbolInCircle() {
        XCTAssertEqual(CanvasIconButtonMetrics.circleDiameter, 22)
        XCTAssertEqual(CanvasIconButtonMetrics.symbolDiameter, 13)
        XCTAssertEqual(CanvasIconButtonMetrics.symbolOrigin, 4.5)
    }

    func testCanvasResizeHandleOverlayTracksScaledBottomRightCorner() {
        let rect = CanvasFrameRect(id: "card", x: 120, y: 80, width: 214 * 1.4, height: 132 * 1.4)

        let center = CanvasResizeHandleGeometry.center(in: rect, zoom: 1.4)
        let hitRect = CanvasResizeHandleGeometry.hitRect(center: center, zoom: 1.4)

        XCTAssertEqual(center.x, rect.x + rect.width - 17 * 1.4, accuracy: 0.0001)
        XCTAssertEqual(center.y, rect.y + rect.height - 17 * 1.4, accuracy: 0.0001)
        XCTAssertTrue(hitRect.width >= 34 * 1.4)
        XCTAssertTrue(CanvasResizeHandleGeometry.contains(center, in: hitRect))
    }

    func testCanvasEdgeControlPointAndHandleScaleWithZoom() {
        let control = CanvasViewportProjection.screenPoint(
            x: 300,
            y: 160,
            zoom: 1.85,
            viewportX: 24,
            viewportY: -10
        )

        XCTAssertEqual(control.x, 579, accuracy: 0.0001)
        XCTAssertEqual(control.y, 286, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeControlHandleMetrics.diameter(zoom: 1.85, baseDiameter: 13), 24.05, accuracy: 0.0001)
    }

    func testCanvasEdgeStyleOptionsKeepBaseStyleWhenLockingAnchor() {
        let locked = CanvasEdgeStyleOptions.style("dashed", controlPointLocked: true)

        XCTAssertTrue(CanvasEdgeStyleOptions.isControlPointLocked(locked))
        XCTAssertEqual(CanvasEdgeStyleOptions.style(locked, controlPointLocked: false), "dashed")
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

    func testCanvasNodeSizePolicyUsesStoredCardSizeWithMinimums() {
        let resource = CanvasNodeSizePolicy.size(
            kind: "resource",
            storedWidth: 360,
            storedHeight: 240,
            defaultWidth: 214,
            defaultHeight: 132,
            minimumWidth: 180,
            minimumHeight: 112
        )
        let note = CanvasNodeSizePolicy.size(
            kind: "note",
            storedWidth: 80,
            storedHeight: 60,
            defaultWidth: 240,
            defaultHeight: 180,
            minimumWidth: 180,
            minimumHeight: 140
        )

        XCTAssertEqual(resource.width, 360)
        XCTAssertEqual(resource.height, 240)
        XCTAssertEqual(note.width, 180)
        XCTAssertEqual(note.height, 140)
    }

    func testCanvasCardTitleLayoutKeepsNoteTitleBoxHalfResourceHeight() {
        let noteHeight = CanvasCardTitleLayoutPolicy.maxTitleHeight(
            kind: "note",
            cardHeight: 180
        )
        let resourceHeight = CanvasCardTitleLayoutPolicy.maxTitleHeight(
            kind: "resource",
            cardHeight: 180
        )

        XCTAssertEqual(noteHeight, resourceHeight / 2)
        XCTAssertEqual(noteHeight, 18)
        XCTAssertEqual(resourceHeight, 36)
    }

    func testCanvasChromeRenderingUsesNativeDrawingForSmallText() {
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.cardHeader))
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.cardDetailLabel))
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.cardDetailBody))
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.frameNote))
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

    func testCanvasZoomBaselineUsesUserPercentAsDisplayedHundredPercent() {
        let baseline = CanvasZoomBaseline.actualZoom(
            percent: 250,
            standardBaseline: 0.35,
            minimum: 0.12,
            maximum: 2.4
        )

        XCTAssertEqual(baseline, 0.875, accuracy: 0.0001)
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: baseline, baseline: baseline), 100)
    }

    func testCanvasZoomScaleAllowsZoomBelowBaseline() {
        XCTAssertEqual(CanvasZoomScale.clamped(0.10, minimum: 0.12, maximum: 2.4), 0.12)
        XCTAssertEqual(CanvasZoomScale.zoom(forDisplayScale: 1, baseline: 0.35, minimum: 0.12, maximum: 2.4), 0.35)
        XCTAssertEqual(CanvasZoomScale.zoom(forDisplayScale: 0.5, baseline: 0.35, minimum: 0.12, maximum: 2.4), 0.175)
    }

    func testCanvasZoomScaleUsesWheelDeltaDirection() {
        let current = 1.0

        XCTAssertGreaterThan(
            CanvasZoomScale.zoom(forScrollDeltaY: -20, current: current, minimum: 0.12, maximum: 2.4),
            current
        )
        XCTAssertLessThan(
            CanvasZoomScale.zoom(forScrollDeltaY: 20, current: current, minimum: 0.12, maximum: 2.4),
            current
        )
    }

    func testCanvasZoomScaleCanReverseWheelDeltaDirection() {
        let current = 1.0

        XCTAssertLessThan(
            CanvasZoomScale.zoom(
                forScrollDeltaY: 20,
                current: current,
                minimum: 0.12,
                maximum: 2.4,
                direction: .scrollDownZoomsOut
            ),
            current
        )
        XCTAssertGreaterThan(
            CanvasZoomScale.zoom(
                forScrollDeltaY: 20,
                current: current,
                minimum: 0.12,
                maximum: 2.4,
                direction: .scrollDownZoomsIn
            ),
            current
        )
    }

    func testCanvasZoomScaleKeepsScreenAnchorStable() {
        let viewport = CanvasZoomScale.viewport(
            keepingScreenX: 300,
            screenY: 200,
            canvasX: 250,
            canvasY: 150,
            zoom: 1.5
        )

        XCTAssertEqual(viewport.x, -75, accuracy: 0.0001)
        XCTAssertEqual(viewport.y, -25, accuracy: 0.0001)
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
