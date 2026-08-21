import SwiftUI

struct ScreenContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
}

struct BottomActionArea<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 10) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

struct GroupedCard<Content: View>: View {
    let title: String?
    let footer: String?
    let trailing: AnyView?
    let content: Content

    init(
        _ title: String? = nil,
        footer: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if title != nil || trailing != nil {
                HStack(alignment: .lastTextBaseline) {
                    if let title {
                        Text(title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    Spacer()
                    trailing
                }
                .padding(.horizontal, 4)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.45), lineWidth: 0.5)
            }

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct BulletListView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.75))
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
    }
}

struct CompetencyTag: View {
    let label: String
    var note: String?
    var muted = false
    var onRemove: (() -> Void)?

    init(label: String, note: String? = nil, muted: Bool = false, onRemove: (() -> Void)? = nil) {
        self.label = label
        self.note = note
        self.muted = muted
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.footnote.weight(.semibold))
                if let note {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(label)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(muted ? Color.secondary : Color.accentColor)
        .background((muted ? Color(.systemGray5) : Color.accentColor.opacity(0.12)), in: Capsule())
    }
}

struct TagCloud: View {
    let tags: [String]
    var muted = false
    var onRemove: ((String) -> Void)?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                CompetencyTag(label: tag, muted: muted, onRemove: onRemove.map { action in
                    { action(tag) }
                })
            }
        }
        .padding(16)
    }
}

struct AssessmentTagCloud: View {
    let assessments: [CompetencyAssessment]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(assessments) { assessment in
                CompetencyTag(
                    label: assessment.name,
                    note: assessment.note,
                    muted: assessment.note == "Not covered"
                )
            }
        }
    }
}

struct QuestionProgressView: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 6)
            }
        }
        .accessibilityLabel("Question \(current) of \(total)")
    }

    private func color(for index: Int) -> Color {
        if index < current - 1 {
            return Color.accentColor.opacity(0.45)
        }
        if index == current - 1 {
            return Color.accentColor
        }
        return Color(.systemGray4)
    }
}

struct InterviewPhaseIndicator: View {
    let phase: InterviewPhase
    let countdown: Int
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if phase == .speaking || phase == .listening {
                    Circle()
                        .fill(indicatorColor.opacity(0.12))
                        .frame(width: 132, height: 132)
                        .scaleEffect(pulse ? 1.15 : 0.92)
                        .opacity(pulse ? 0.25 : 0.7)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                }

                Circle()
                    .fill(indicatorColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Circle()
                            .stroke(indicatorColor.opacity(0.25), lineWidth: 1)
                    }

                indicatorContent
            }
            .frame(width: 140, height: 140)

            if phase == .listening || phase == .processing {
                Image(systemName: phase == .listening ? "mic.fill" : "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(indicatorColor)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground), in: Circle())
                    .overlay {
                        Circle().stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)
            }
        }
        .onAppear { pulse = true }
        .onChange(of: phase) { _, _ in
            pulse = false
            pulse = true
        }
        .accessibilityLabel(phase.title)
    }

    @ViewBuilder
    private var indicatorContent: some View {
        switch phase {
        case .speaking:
            Image(systemName: "waveform")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(indicatorColor)
        case .listening:
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(indicatorColor)
        case .paused:
            VStack(spacing: 2) {
                Image(systemName: "pause.fill")
                    .font(.title2.weight(.semibold))
                Text("\(countdown)")
                    .font(.caption.monospacedDigit().weight(.bold))
            }
            .foregroundStyle(indicatorColor)
        case .processing:
            ProgressView()
                .tint(indicatorColor)
                .scaleEffect(1.4)
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.green)
        }
    }

    private var indicatorColor: Color {
        switch phase {
        case .speaking, .processing:
            return .accentColor
        case .listening, .finished:
            return .green
        case .paused:
            return .orange
        }
    }
}

struct FeedbackCard<Content: View>: View {
    let title: String
    let caption: String?
    let content: Content

    init(_ title: String, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                if let caption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
    }
}

struct FeedbackPointRow: View {
    let point: FeedbackPoint
    var symbol = "checkmark.circle.fill"
    var tint: Color = .green

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(point.point)
                    .font(.subheadline.weight(.semibold))
                if let detail = point.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(in: maxWidth, subviews: subviews)
        return CGSize(width: maxWidth, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    let items: [FlowItem]
    let height: CGFloat
}

private struct FlowItem {
    let index: Int
    let size: CGSize
}
