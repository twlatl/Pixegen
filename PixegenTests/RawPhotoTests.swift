import AppKit
import Testing
@testable import Pixegen

/// A RAW's layer, which the toolbar's Camera RAW button grades again from the frame as developed at import (PBX-34).
@MainActor
struct RawPhotoTests {
    private func gray(_ value: CGFloat, width: Int = 8, height: Int = 8) throws -> ImportedImage {
        let context = try BrushRaster.context(width: width, height: height, mask: false)
        context.setFillColor(CGColor(srgbRed: value, green: value, blue: value, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        return try DeepLayer.asset(image, name: "Photo")
    }

    private func red(_ image: CGImage) throws -> Int {
        let context = try BrushRaster.context(width: image.width, height: image.height, mask: false)
        BrushRaster.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height), mask: false, context: context)
        return Int(try #require(context.data).assumingMemoryBound(to: UInt8.self)[0])
    }

    private func raise(_ session: EditorSession, exposure: Double) async throws {
        var settings = try #require(session.filterEdit).settings
        settings.cameraRaw.exposure = exposure
        session.updateFilter(settings, preview: true)
        await session.commitFilter()
    }

    @Test func cameraRawRegradesTheOriginalFrame() async throws {
        let session = EditorSession()
        session.createDocument(width: 8, height: 8)
        let frame = try gray(0.5)
        session.insertRawPhoto(frame)
        #expect(session.showsCameraRawButton && session.canEditRawPhoto)
        let start = try red(frame.image)

        session.editRawPhoto()
        #expect(session.filterEdit?.kind == .cameraRaw && session.filterEdit?.rawPhoto != nil)
        #expect(!session.canEditRawPhoto, "the button waits while the panel is open")
        try await raise(session, exposure: 1)
        let once = try red(try #require(session.activeLayer?.asset?.image))
        #expect(once > start + 20, "graded: \(start) → \(once)")
        #expect(session.activeRawPhoto?.settings.exposure == 1)

        // Opened again, it starts at the layer's settings, over the original rather than the graded pixels.
        session.editRawPhoto()
        #expect(session.filterEdit?.settings.cameraRaw.exposure == 1)
        #expect(session.filterEdit?.original.image === frame.image)
        try await raise(session, exposure: 0.5)
        session.editRawPhoto()
        try await raise(session, exposure: 1)
        #expect(abs(try red(try #require(session.activeLayer?.asset?.image)) - once) <= 1, "not graded twice over")

        // Taken back to nothing, the frame is as it was developed.
        session.editRawPhoto()
        try await raise(session, exposure: 0)
        #expect(session.activeLayer?.asset?.image === frame.image)
        #expect(session.showsCameraRawButton)

        session.undo()
        #expect(session.activeRawPhoto?.settings.exposure == 1, "undo brings the grade back with the pixels")
    }

    @Test func otherEditsMakeThePhotoPlainPixels() async throws {
        let session = EditorSession()
        session.createDocument(width: 8, height: 8)
        session.insertRawPhoto(try gray(0.5))
        session.beginFilter(.exposure)
        var settings = try #require(session.filterEdit).settings
        settings.exposure.exposure = 1
        session.updateFilter(settings, preview: true)
        await session.commitFilter()
        #expect(!session.showsCameraRawButton, "an Exposure filter replaced the developed pixels")

        let plain = EditorSession()
        plain.createDocument(width: 8, height: 8)
        plain.insert(try gray(0.5))
        #expect(!plain.showsCameraRawButton)
    }
}
