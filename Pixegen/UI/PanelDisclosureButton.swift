import SwiftUI

/// The triangle at the right of a sidebar panel's title row that folds the panel down to that row and opens it again:
/// pointing down while the panel is open, left while it's folded.
struct PanelDisclosureButton: View {
    @Binding var isCollapsed: Bool
    /// The panel's name, for the help tag and VoiceOver: "Collapse Layers".
    let panel: String

    var body: some View {
        Button { isCollapsed.toggle() } label: {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9))
                // A quarter turn clockwise: down to left.
                .rotationEffect(.degrees(isCollapsed ? 90 : 0))
                .foregroundStyle(.secondary)
                // The whole square takes the click, as the title row's other icons do.
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? "Expand \(panel)" : "Collapse \(panel)")
        .accessibilityLabel(isCollapsed ? "Expand \(panel)" : "Collapse \(panel)")
    }
}
