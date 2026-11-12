import AppKit
import Testing
@testable import Pixegen

/// The modifier keys of the Shape and Pen tools, through the canvas: what a press, a drag and a key do with Shift,
/// Option, Command and Space held.
///
/// Shape drags hold Control as well, which turns off snapping to the canvas and the other layers
/// (`snappedCorner`), so a corner lands on the pixel it was dragged to.
@MainActor
struct VectorModifierKeyTests {
    private func makeCanvas(_ tool: NavigationTool) throws -> (EditorSession, CanvasView, NSWindow) {
        let session = EditorSession()
        session.createDocument(width: 400, height: 300, emptyLayer: true)
        session.selectTool(tool)
        session.foregroundColor = PaletteColor(red: 1, green: 0, blue: 0)
        let view = CanvasView(session: session)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = view
        session.viewport.resize(to: view.bounds.size, backingScale: 1, documentSize: try #require(session.document?.size))
        view.synchronizeDisplay()
        return (session, view, window)
    }

    private func mouse(_ type: NSEvent.EventType, _ session: EditorSession, _ view: CanvasView, in window: NSWindow, at point: CGPoint,
                       flags: NSEvent.ModifierFlags = []) throws {
        let size = try #require(session.document?.size)
        let spot = session.viewport.viewPoint(from: point, documentSize: size)
        let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: spot.x, y: view.bounds.height - spot.y),
            modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        switch type {
        case .leftMouseDown: view.mouseDown(with: event)
        case .leftMouseDragged: view.mouseDragged(with: event)
        default: view.mouseUp(with: event)
        }
    }
    private func drag(_ session: EditorSession, _ view: CanvasView, in window: NSWindow, from start: CGPoint, to end: CGPoint,
                      flags: NSEvent.ModifierFlags = []) throws {
        try mouse(.leftMouseDown, session, view, in: window, at: start, flags: flags)
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2), flags: flags)
        try mouse(.leftMouseDragged, session, view, in: window, at: end, flags: flags)
        try mouse(.leftMouseUp, session, view, in: window, at: end, flags: flags)
    }
    private func key(_ view: CanvasView, in window: NSWindow, code: UInt16, characters: String, down: Bool = true,
                     flags: NSEvent.ModifierFlags = []) throws {
        let event = try #require(NSEvent.keyEvent(with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: false, keyCode: code))
        if down { view.keyDown(with: event) } else { view.keyUp(with: event) }
    }
    private func near(_ a: CGPoint, _ b: CGPoint, within tolerance: CGFloat = 1) -> Bool { hypot(a.x - b.x, a.y - b.y) <= tolerance }
    private func anchors(_ session: EditorSession) -> [CGPoint] {
        session.pathKnotsInDocument?.flatMap { $0.knots.map(\.anchor) } ?? []
    }
    private func frame(_ session: EditorSession) -> CGRect? {
        session.activeLayer.map { CGRect(origin: $0.transform.origin, size: $0.transform.size) }
    }

    // MARK: Shape

    @Test func shiftAndOptionSquareAShapeAndDrawItFromItsCenter() throws {
        let (session, view, window) = try makeCanvas(.shape)
        try drag(session, view, in: window, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 110), flags: [.shift, .control])
        #expect(frame(session) == CGRect(x: 50, y: 50, width: 100, height: 100), "\(String(describing: frame(session)))")
        // A layer that isn't a shape is nothing to add to, so Option here is only from the center.
        session.selectLayer(session.document?.layers.first?.id)
        try drag(session, view, in: window, from: CGPoint(x: 300, y: 150), to: CGPoint(x: 340, y: 170), flags: [.option, .control])
        #expect(frame(session) == CGRect(x: 260, y: 130, width: 80, height: 40), "\(String(describing: frame(session)))")
        #expect(session.document?.layers.count == 3)
    }

    @Test func shiftAtThePressAddsToTheActiveShapeAndSquaresOnlyOncePressedAgain() throws {
        let (session, view, window) = try makeCanvas(.shape)
        try drag(session, view, in: window, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 120), flags: .control)
        #expect(session.document?.layers.count == 2)
        try drag(session, view, in: window, from: CGPoint(x: 100, y: 80), to: CGPoint(x: 220, y: 200), flags: [.shift, .control])
        #expect(session.document?.layers.count == 2, "added to the rectangle, not a layer of its own")
        #expect(frame(session) == CGRect(x: 50, y: 50, width: 170, height: 150), "\(String(describing: frame(session)))")
        #expect(session.activeLayer?.liveShape?.style.kind == .custom)
        // Shift let go and pressed again mid-drag squares what is being added.
        try mouse(.leftMouseDown, session, view, in: window, at: CGPoint(x: 200, y: 180), flags: [.shift, .control])
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 230, y: 190), flags: .control)
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 260, y: 200), flags: [.shift, .control])
        #expect(session.shapeDraft?.rect == CGRect(x: 200, y: 180, width: 60, height: 60))
        try mouse(.leftMouseUp, session, view, in: window, at: CGPoint(x: 260, y: 200), flags: [.shift, .control])
        #expect(session.document?.layers.count == 2)
        #expect(frame(session) == CGRect(x: 50, y: 50, width: 210, height: 190), "\(String(describing: frame(session)))")
    }

    @Test func optionAtThePressCutsTheNewShapeOutOfTheActiveOne() throws {
        let (session, view, window) = try makeCanvas(.shape)
        try drag(session, view, in: window, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 120), flags: .control)
        // Across the rectangle's right end, from a corner rather than a center: what is left is narrower.
        try drag(session, view, in: window, from: CGPoint(x: 120, y: 20), to: CGPoint(x: 200, y: 200), flags: [.option, .control])
        #expect(session.document?.layers.count == 2)
        #expect(frame(session) == CGRect(x: 50, y: 50, width: 70, height: 70), "\(String(describing: frame(session)))")
    }

    @Test func spaceMovesTheShapeBeingDrawnUntilItIsLetGo() throws {
        let (session, view, window) = try makeCanvas(.shape)
        try mouse(.leftMouseDown, session, view, in: window, at: CGPoint(x: 50, y: 50), flags: .control)
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 100, y: 90), flags: .control)
        try key(view, in: window, code: 49, characters: " ")
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 100, y: 90), flags: .control)
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 140, y: 120), flags: .control)
        #expect(session.shapeDraft?.rect == CGRect(x: 90, y: 80, width: 50, height: 40))
        try key(view, in: window, code: 49, characters: " ", down: false)
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 160, y: 150), flags: .control)
        try mouse(.leftMouseUp, session, view, in: window, at: CGPoint(x: 160, y: 150), flags: .control)
        #expect(frame(session) == CGRect(x: 90, y: 80, width: 70, height: 70), "\(String(describing: frame(session)))")
    }

    // MARK: Pen

    /// A triangle with the Pen: (100, 50), (200, 50), (150, 150).
    private func triangle(_ session: EditorSession, _ view: CanvasView, in window: NSWindow) throws {
        for point in [CGPoint(x: 100, y: 50), CGPoint(x: 200, y: 50), CGPoint(x: 150, y: 150), CGPoint(x: 100, y: 50)] {
            try mouse(.leftMouseDown, session, view, in: window, at: point)
            try mouse(.leftMouseUp, session, view, in: window, at: point)
        }
    }

    @Test func commandWithThePenDragsAPointAsDirectSelectionDoes() throws {
        let (session, view, window) = try makeCanvas(.pen)
        try triangle(session, view, in: window)
        #expect(session.document?.layers.count == 2)
        try drag(session, view, in: window, from: CGPoint(x: 200, y: 50), to: CGPoint(x: 230, y: 30), flags: .command)
        #expect(session.penDraft == nil, "no new path was begun")
        #expect(anchors(session).contains { near($0, CGPoint(x: 230, y: 30)) }, "\(anchors(session))")
        #expect(session.document?.layers.count == 2)
    }

    @Test func optionWithThePenIsConvertPointOnAPointAndThePenAnywhereElse() throws {
        let (session, view, window) = try makeCanvas(.pen)
        try triangle(session, view, in: window)
        try drag(session, view, in: window, from: CGPoint(x: 150, y: 150), to: CGPoint(x: 180, y: 150), flags: .option)
        #expect(session.penDraft == nil)
        let knot = try #require(session.pathKnotsInDocument?.flatMap(\.knots).first { near($0.anchor, CGPoint(x: 150, y: 150)) })
        #expect(near(knot.outgoing, CGPoint(x: 180, y: 150)) && near(knot.incoming, CGPoint(x: 120, y: 150)), "\(knot)")
        // Away from any point Option changes nothing about a press: the Pen places one.
        try mouse(.leftMouseDown, session, view, in: window, at: CGPoint(x: 300, y: 250), flags: .option)
        try mouse(.leftMouseUp, session, view, in: window, at: CGPoint(x: 300, y: 250), flags: .option)
        #expect(session.penDraft?.knots.count == 1)
    }

    @Test func spaceMovesThePenPointBeingPlaced() throws {
        let (session, view, window) = try makeCanvas(.pen)
        try mouse(.leftMouseDown, session, view, in: window, at: CGPoint(x: 100, y: 100))
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 130, y: 100))
        try key(view, in: window, code: 49, characters: " ")
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 130, y: 100))
        try mouse(.leftMouseDragged, session, view, in: window, at: CGPoint(x: 160, y: 140))
        try key(view, in: window, code: 49, characters: " ", down: false)
        try mouse(.leftMouseUp, session, view, in: window, at: CGPoint(x: 160, y: 140))
        let knot = try #require(session.penDraft?.knots.first)
        #expect(near(knot.anchor, CGPoint(x: 130, y: 140)) && near(knot.outgoing, CGPoint(x: 160, y: 140)), "\(knot)")
    }

    @Test func commandReturnWithThePenMakesThePathASelection() throws {
        let (session, view, window) = try makeCanvas(.pen)
        for point in [CGPoint(x: 100, y: 50), CGPoint(x: 200, y: 50), CGPoint(x: 150, y: 150)] {
            try mouse(.leftMouseDown, session, view, in: window, at: point)
            try mouse(.leftMouseUp, session, view, in: window, at: point)
        }
        try key(view, in: window, code: 36, characters: "\r", flags: .command)
        #expect(session.penDraft == nil && session.document?.layers.count == 1)
        #expect(session.selection?.path.contains(CGPoint(x: 150, y: 80)) == true)
    }
}
