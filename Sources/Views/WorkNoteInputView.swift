import SwiftUI

struct WorkNoteInputView: View {
    @Binding var notes: [String]
    let suggestions: [String]

    @State private var inputText = ""
    @State private var selectedSuggestion: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("作業内容")
                .font(.caption)
                .foregroundColor(.secondary)

            if !availableSuggestions.isEmpty {
                Picker("候補から選択", selection: $selectedSuggestion) {
                    Text("候補から追加…").tag(String?.none)
                    ForEach(availableSuggestions, id: \.self) { suggestion in
                        Text(suggestion).tag(String?.some(suggestion))
                    }
                }
                .labelsHidden()
                .onChange(of: selectedSuggestion) { _, newValue in
                    if let value = newValue {
                        notes.append(value)
                        selectedSuggestion = nil
                    }
                }
            }

            HStack {
                TextField("作業内容を入力…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addCurrentInput() }
                Button("追加") { addCurrentInput() }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !notes.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                        HStack(spacing: 4) {
                            Text(note)
                                .font(.callout)
                            Button { notes.remove(at: index) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var availableSuggestions: [String] {
        suggestions.filter { !notes.contains($0) }
    }

    private func addCurrentInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !notes.contains(trimmed) else { return }
        notes.append(trimmed)
        inputText = ""
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (rowIndex, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if rowIndex > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var originY = bounds.minY
        for (rowIndex, row) in rows.enumerated() {
            if rowIndex > 0 { originY += spacing }
            var originX = bounds.minX
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: originX, y: originY), proposal: ProposedViewSize(size))
                originX += size.width + spacing
            }
            originY += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0
        for (subIndex, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].isEmpty && currentWidth + spacing + size.width > maxWidth {
                rows.append([])
                currentWidth = 0
            }
            if currentWidth > 0 { currentWidth += spacing }
            currentWidth += size.width
            rows[rows.count - 1].append(subIndex)
        }
        return rows
    }
}
