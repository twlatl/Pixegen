import SwiftUI

/// The Align panel at the top of the right sidebar, above Color: Align, Distribute and stacking order for the selected
/// layers, whatever tool is in hand. The triangle at its right folds it to its title row.
struct ArrangePanel: View {
    @Bindable var session: EditorSession
    var width: CGFloat = 252
    /// Folded down to its title row by the triangle at its right.
    @AppStorage("alignPanel.collapsed") private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                // The title folds and opens the panel too.
                Text("Align").font(.system(size: 12, weight: .semibold))
                    .contentShape(Rectangle()).onTapGesture { isCollapsed.toggle() }
                Spacer()
                PanelDisclosureButton(isCollapsed: $isCollapsed, panel: "Align")
                    // Into the row's padding by the square's slack, so it lines up with the triangles below.
                    .padding(.horizontal, -8)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            if !isCollapsed {
                content.padding(.horizontal, 18).padding(.bottom, 12)
                    .disabled(session.showsBusy)
            }
        }
        .frame(width: width)
    }

    /// Everything under the title row. Sized to fit the sidebar at its narrowest.
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(LayerAlignment.aligns)
            labeled("Distribute") { row(LayerAlignment.distributes) }
            HStack(alignment: .top, spacing: 0) {
                labeled("Spacing") {
                    HStack(spacing: 6) { ForEach(LayerAlignment.spacings, id: \.self, content: button) }
                }
                Spacer(minLength: 12)
                labeled("Order") {
                    HStack(spacing: 6) {
                        ForEach([LayerArrangement.back, .backward, .forward, .front], id: \.self, content: orderButton)
                    }
                }
            }
            HStack(spacing: 6) {
                Text("Align To").font(.system(size: 11)).foregroundStyle(.secondary)
                Picker("Align To", selection: $session.alignmentTarget) {
                    ForEach(AlignmentTarget.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().fixedSize().controlSize(.small)
                .help("Line layers up against the box around them all, or against the canvas. One layer always lines up with the canvas.")
            }
        }
    }

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            content()
        }
    }

    private func orderButton(_ arrangement: LayerArrangement) -> some View {
        let enabled = session.canArrange(arrangement)
        // The tip sits on a wrapper: a disabled button shows none of its own.
        return HStack {
            Button { session.arrange(arrangement) } label: {
                Image(systemName: arrangement.systemImage).font(.system(size: 15)).frame(width: 24, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!enabled)
            .accessibilityLabel(arrangement.rawValue)
        }
        .help(arrangement.rawValue)
    }

    /// Six buttons, the across three apart from the up-and-down three.
    private func row(_ alignments: [LayerAlignment]) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) { ForEach(alignments.prefix(3), id: \.self, content: button) }
            Spacer(minLength: 12)
            HStack(spacing: 6) { ForEach(alignments.suffix(3), id: \.self, content: button) }
        }
    }

    private func button(_ alignment: LayerAlignment) -> some View {
        let enabled = session.canAlign(alignment)
        // The tip sits on a wrapper: a disabled button shows none of its own, and that's when it has most to say.
        return HStack {
            Button { session.align(alignment) } label: {
                Image(systemName: alignment.systemImage).font(.system(size: 15)).frame(width: 24, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!enabled)
            .accessibilityLabel(alignment.rawValue)
        }
        .help(alignment.isDistribution && !enabled ? "\(alignment.rawValue) (select three or more layers)" : alignment.rawValue)
    }
}
