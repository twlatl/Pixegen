import AppKit

/// A layer opened from a camera RAW file. The frame as it was developed at import stays with the layer, with the Camera
/// Raw settings now on it, so the toolbar's Camera RAW button opens those settings again over the original rather than
/// grading pixels that were already graded. Kept for the session; a saved project holds the layer's pixels alone.
struct RawPhoto: Equatable {
    /// The frame developed at the camera's own settings, at 16 bits a channel.
    let original: ImportedImage
    var settings: CameraRawSettings
    /// The pixels Camera Raw last put on the layer. Painted, filtered or resized since, the layer is plain pixels again.
    let developed: CGImage

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.original.image === rhs.original.image && lhs.settings == rhs.settings && lhs.developed === rhs.developed
    }
}

extension EditorSession {
    /// The layer's RAW, while the layer still shows what Camera Raw last made of it.
    func rawPhoto(of layer: ImageLayer) -> RawPhoto? {
        guard let raw = layer.rawPhoto, layer.gifAnimation == nil, layer.asset?.image === raw.developed else { return nil }
        return raw
    }
    var activeRawPhoto: RawPhoto? { activeLayer.flatMap(rawPhoto(of:)) }

    /// The toolbar's Camera RAW button: shown while a RAW's layer is active.
    var showsCameraRawButton: Bool { activeRawPhoto != nil && !isMaskSelected }
    var canEditRawPhoto: Bool { showsCameraRawButton && filterEdit == nil && hueSaturation == nil && levels == nil }

    /// Opens the Camera Raw panel on the active RAW, at the settings it has now.
    func editRawPhoto() {
        guard canEditRawPhoto else { NSSound.beep(); return }
        beginFilter(.cameraRaw)
    }

    /// Puts a RAW's developed frame in as a new layer that remembers where it came from.
    func insertRawPhoto(_ asset: ImportedImage, centeredAt point: CGPoint? = nil) {
        beginEdit("Import Image")
        defer { endEdit() }
        insert(asset, centeredAt: point)
        guard let index = document?.layers.firstIndex(where: { $0.id == activeLayerID }) else { return }
        document?.layers[index].rawPhoto = RawPhoto(original: asset, settings: CameraRawSettings(), developed: asset.image)
    }
}
