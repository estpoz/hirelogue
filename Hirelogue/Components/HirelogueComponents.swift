import SwiftUI

// MARK: - Screen and Action Containers

/// Full-screen wrapper that applies the app's grouped background.
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

/// Bottom button area used for primary actions that should stay reachable.
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
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Grouped Content

/// iOS-style grouped section with an optional heading, trailing control, and footer.
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

/// Two-column row for label/value information inside a grouped card.
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

/// Vertical bullet list used for responsibilities and qualifications.
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

// MARK: - Tags and Progress

/// Pill-style competency label with optional assessment note and remove action.
struct CompetencyTag: View {
    let label: String
    var note: String?
    var symbol: String?
    var tint: Color?
    var muted = false
    var onRemove: (() -> Void)?

    init(
        label: String,
        note: String? = nil,
        symbol: String? = nil,
        tint: Color? = nil,
        muted: Bool = false,
        onRemove: (() -> Void)? = nil
    ) {
        self.label = label
        self.note = note
        self.symbol = symbol
        self.tint = tint
        self.muted = muted
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
            }

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
        .foregroundStyle(tagTint)
        .background(tagBackground, in: Capsule())
    }

    private var tagTint: Color {
        if let tint {
            return tint
        }
        return muted ? Color.secondary : Color.accentColor
    }

    private var tagBackground: Color {
        if let tint {
            return tint.opacity(0.12)
        }
        return muted ? Color(.systemGray5) : Color.accentColor.opacity(0.12)
    }
}

/// Wrapping collection of editable competency tags.
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

/// Wrapping collection of read-only feedback competency assessments.
struct AssessmentTagCloud: View {
    let assessments: [CompetencyAssessment]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(assessments) { assessment in
                CompetencyTag(
                    label: assessment.name,
                    note: assessment.note,
                    symbol: symbol(for: assessment),
                    tint: tint(for: assessment),
                    muted: assessment.note == "Not covered"
                )
            }
        }
    }

    private func symbol(for assessment: CompetencyAssessment) -> String {
        switch assessment.note {
        case "Clearly explained":
            return "checkmark.circle.fill"
        case "Partly explained":
            return "exclamationmark.circle.fill"
        case "Not covered":
            return "minus.circle.fill"
        default:
            return "info.circle.fill"
        }
    }

    private func tint(for assessment: CompetencyAssessment) -> Color {
        switch assessment.note {
        case "Clearly explained":
            return .green
        case "Partly explained":
            return .orange
        case "Not covered":
            return .secondary
        default:
            return .accentColor
        }
    }
}

/// Segmented progress bar for the current interview question.
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

// MARK: - Interview State Indicator

/// Circular visual indicator for the current mock interview phase.
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

    /// Icon or progress content displayed inside the circular phase indicator.
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

    /// Semantic tint for each phase.
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

// MARK: - Feedback Components

/// Reusable feedback card with a title, optional caption, and custom body.
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

/// One feedback row with a configurable status symbol.
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

// MARK: - Empty States

/// Generic empty-state view with an icon, message, and recovery action.
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

// MARK: - Layout Helpers

/// Simple wrapping layout used by competency tag collections.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    /// Measures the height needed after wrapping subviews into rows.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(in: maxWidth, subviews: subviews)
        return CGSize(width: maxWidth, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing)
    }

    /// Places each row left-to-right, then moves down by the tallest item in that row.
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

    /// Groups subviews into rows based on the available width.
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

/// Internal row representation used by FlowLayout placement.
private struct FlowRow {
    let items: [FlowItem]
    let height: CGFloat
}

/// Internal measured item representation used by FlowLayout placement.
private struct FlowItem {
    let index: Int
    let size: CGSize
}

// MARK: - Component Previews

#Preview("Grouped Components") {
    ScreenContainer {
        ScrollView {
            VStack(spacing: 18) {
                GroupedCard(
                    "Job profile",
                    footer: "This mirrors the extracted job profile section.",
                    trailing: AnyView(Button("Edit") {})
                ) {
                    InfoRow(label: "Position", value: "iOS Developer")
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Seniority", value: "Mid-level")
                }

                GroupedCard("Responsibilities") {
                    BulletListView(items: [
                        "Build SwiftUI features for a consumer banking app",
                        "Collaborate with backend engineers on REST APIs",
                        "Improve reliability with unit and UI tests"
                    ])
                }
            }
            .padding(.vertical, 20)
        }
    }
}

#Preview("Tags and Progress") {
    ScreenContainer {
        VStack(alignment: .leading, spacing: 24) {
            GroupedCard("Competencies") {
                TagCloud(tags: [
                    "Swift",
                    "SwiftUI",
                    "Concurrency",
                    "Testing",
                    "Performance"
                ]) { _ in }
            }

            FeedbackCard("Assessment Tags") {
                AssessmentTagCloud(assessments: [
                    CompetencyAssessment(name: "SwiftUI", note: "Clearly explained"),
                    CompetencyAssessment(name: "Concurrency", note: "Partly explained"),
                    CompetencyAssessment(name: "Testing", note: "Not covered")
                ])
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Interview progress")
                    .font(.headline)
                QuestionProgressView(total: 5, current: 3)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
}

#Preview("Interview States") {
    ScreenContainer {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 18) {
                ForEach(InterviewPhase.allCases) { phase in
                    VStack(spacing: 8) {
                        InterviewPhaseIndicator(phase: phase, countdown: 2)
                        Text(phase.title)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(16)
        }
    }
}

#Preview("Feedback Components") {
    ScreenContainer {
        ScrollView {
            VStack(spacing: 16) {
                FeedbackCard("Strengths demonstrated", caption: "How feedback points render with detail text.") {
                    VStack(alignment: .leading, spacing: 14) {
                        FeedbackPointRow(
                            point: FeedbackPoint(
                                point: "You named specific technical decisions.",
                                detail: "You explained when SwiftUI was a better fit and why UIKit stayed in one flow."
                            )
                        )
                        FeedbackPointRow(
                            point: FeedbackPoint(
                                point: "The testing example needs more detail.",
                                detail: "Add what the test caught and how it reduced release risk."
                            ),
                            symbol: "exclamationmark.circle.fill",
                            tint: .orange
                        )
                    }
                }

                BottomActionArea {
                    Button("Primary Action") {}
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button("Secondary Action") {}
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding(.vertical, 20)
        }
    }
}

#Preview("Empty State") {
    ScreenContainer {
        EmptyStateView(
            title: "No job profile yet",
            message: "Paste a job opening on the home screen to prepare an interview.",
            actionTitle: "Go to Home",
            action: {}
        )
    }
}
