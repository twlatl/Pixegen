import SwiftUI
import AppKit

/// The picker for a color in a filter panel, the layer effects or a dialog: saturation/brightness field, vertical hue
/// strip, preview, RGB and hex entry, with OK and Cancel. It lives in a movable floating panel, so the panel or dialog
/// that opened it isn't covered by a popover and the canvas stays visible. What it edits follows its color live.
struct ColorPickerSheet: View {
    let session: EditorSession
    @Bindable var state: ColorPickerState
    let finish: (Bool) -> Void
    @State private var hexDraft = ""
    @FocusState private var hexFocused: Bool
    private let fieldSize: CGFloat = 256

    private var hsb: PickerHSB {
        get { state.hsb }
        nonmutating set { state.hsb = newValue }
    }
    private var color: PaletteColor { state.color }
    /// A dialog covers the canvas, so its colors can't be sampled from it.
    private var samples: Bool { !session.pickingForDialog && session.document != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SaturationBrightnessField(hsb: Binding(get: { hsb }, set: { hsb = $0 }),
                                      size: CGSize(width: fieldSize, height: fieldSize))
            HueStrip(hue: Binding(get: { hsb.hue }, set: { hsb.hue = $0 }), height: fieldSize)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    preview
                    VStack(spacing: 8) {
                        Button { finish(true) } label: { Text("OK").frame(maxWidth: .infinity) }
                            .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
                        Button { finish(false) } label: { Text("Cancel").frame(maxWidth: .infinity) }
                            .configuredNativeShortcut(.escape)
                    }
                    .controlSize(.large).frame(width: 90)
                }
                Spacer(minLength: 12)
                fields
                if samples {
                    Button { session.beginEyedropper(intoPicker: true) } label: {
                        Label("Pick from the canvas", systemImage: "eyedropper")
                    }
                    .buttonStyle(.borderless).font(.caption)
                    .foregroundStyle(session.eyedropper?.intoPicker == true ? Color.accentColor : .secondary)
                    .help("Pick a color from the canvas")
                    .padding(.top, 8)
                }
            }
            .frame(width: 180, height: fieldSize, alignment: .topLeading)
        }
        .padding(20)
        .fixedSize()
        .onAppear { hexDraft = color.hex }
        .onChange(of: color) { _, new in
            if !hexFocused { hexDraft = new.hex }
            state.colorChanged()
            session.previewPickerColor()
        }
        .onChange(of: hexFocused) { _, focused in if !focused { commitHex() } }
    }

    private var preview: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(color.swiftUI)
            .overlay { RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.black.opacity(0.6), lineWidth: 1) }
            .frame(width: 64, height: 64)
            .accessibilityLabel("New color")
    }

    private var fields: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            channelRow("R", \.red)
            channelRow("G", \.green)
            channelRow("B", \.blue)
            GridRow {
                Text("#").frame(width: 14, alignment: .leading)
                TextField("Hex", text: $hexDraft)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 84)
                    .focused($hexFocused)
                    .onSubmit(commitHex)
                    .accessibilityLabel("Hex color")
            }
        }
    }

    private func channelRow(_ label: String, _ channel: WritableKeyPath<PaletteColor, CGFloat>) -> some View {
        let channelValue = Binding<Int>(
            get: { Int((color[keyPath: channel] * 255).rounded()) },
            set: { newValue in
                var rgb = color
                rgb[keyPath: channel] = CGFloat(min(255, max(0, newValue))) / 255
                hsb.setRGB(rgb)
            })
        return GridRow {
            Text(label).frame(width: 14, alignment: .leading)
                .scrubbable(sensitivity: 1, value: channelValue, range: 0...255)
            TextField(label, value: channelValue, format: .number)
                .frame(width: 52)
                .arrowSteps(value: { Double(Int((color[keyPath: channel] * 255).rounded())) },
                            change: { newValue in
                                var rgb = color
                                rgb[keyPath: channel] = CGFloat(min(255, max(0, newValue.rounded()))) / 255
                                hsb.setRGB(rgb)
                            })
                .accessibilityLabel(label == "R" ? "Red" : label == "G" ? "Green" : "Blue")
        }
    }

    private func commitHex() {
        if let parsed = PaletteColor(hex: hexDraft) { hsb.setRGB(parsed) }
        hexDraft = color.hex
    }
}

/// Hosts `ColorPickerSheet` in its own floating panel: first opened centered on the canvas, afterwards wherever it
/// was last left. Closing it with the title-bar button cancels.
@MainActor
final class ColorPickerPanelController: NSObject {
    static let identifier = NSUserInterfaceItemIdentifier("colorPickerPanel")
    private let panel = FloatingPanelController(name: "colorPickerPanel")

    func show(_ state: ColorPickerState, session: EditorSession) {
        panel.onClose = { [weak session] in
            guard let session, session.colorPicker === state else { return }
            if session.eyedropper?.intoPicker == true { session.finishEyedropper(commit: false) }
            session.closeColorPicker(commit: false)
        }
        panel.show(title: state.target.title,
                   content: ColorPickerSheet(session: session, state: state) { [weak session] commit in
                       if session?.eyedropper?.intoPicker == true { session?.finishEyedropper(commit: false) }
                       session?.closeColorPicker(commit: commit)
                   })
    }

    func close() { panel.close() }

    /// Returns keyboard focus to the picker after a click on the canvas sampled a color.
    static func refocus() { FloatingPanelController.refocus(identifier) }
}
