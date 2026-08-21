import SwiftUI

/// Simulated voice-interview screen.
///
/// This view intentionally shows no transcript. It visualizes future speaking,
/// listening, pause, processing, and finished states using view-model timers.
struct InterviewSessionView: View {
    // MARK: - Dependencies

    @Bindable var viewModel: InterviewSessionViewModel

    /// Called when the interview ends naturally or through the confirmation dialog.
    let onShowFeedback: () -> Void

    /// Called only for the fallback empty state.
    let onGoHome: () -> Void

    // MARK: - Local UI State

    @State private var showEndConfirmation = false
    @State private var showDemoControls = false

    // MARK: - Body

    var body: some View {
        ScreenContainer {
            if viewModel.jobProfile == nil {
                EmptyStateView(
                    title: "No interview prepared",
                    message: "Start from the home screen to prepare a practice interview.",
                    actionTitle: "Go to Home",
                    action: onGoHome
                )
            } else {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    centerStage
                    Spacer(minLength: 0)
                    footer
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .confirmationDialog(
                    "End this interview?",
                    isPresented: $showEndConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("End Interview", role: .destructive) {
                        viewModel.endInterview()
                        onShowFeedback()
                    }
                    Button("Continue Interview", role: .cancel) {}
                } message: {
                    Text("Your current practice session will end and feedback may be incomplete.")
                }
                .onChange(of: viewModel.shouldShowFeedback) { _, shouldShow in
                    if shouldShow {
                        onShowFeedback()
                    }
                }
            }
        }
    }

    // MARK: - Header

    /// Fixed top status bar with progress, remaining time, and the protected End action.
    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview in Progress")
                        .font(.headline)
                    Text(viewModel.questionProgressTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(viewModel.formattedRemainingTime, systemImage: "clock")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5), in: Capsule())
                Button("End", role: .destructive) {
                    showEndConfirmation = true
                }
                .font(.body.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Center Stage

    /// Main interview state presentation. The question is visible only while "speaking".
    private var centerStage: some View {
        ScrollView {
            VStack(spacing: 22) {
                InterviewPhaseIndicator(phase: viewModel.phase, countdown: viewModel.pauseCountdown)

                VStack(spacing: 8) {
                    Text(viewModel.phase.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if viewModel.phase == .paused {
                        Text("Continuing in \(viewModel.pauseCountdown)s")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Text(viewModel.phase.instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if viewModel.phase == .speaking {
                    questionCard
                }

                if viewModel.phase == .paused {
                    Button {
                        viewModel.continueSpeaking()
                    } label: {
                        Label("Simulate Speaking", systemImage: "waveform")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    /// Card for the current interviewer question or follow-up prompt.
    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(viewModel.isFollowUp ? "Follow-up question" : "Question \(viewModel.questionIndex + 1)") - \(viewModel.currentQuestion.competency)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(viewModel.currentQuestionText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 0.5)
        }
    }

    // MARK: - Footer

    /// Bottom progress bar and prototype-only controls for manually testing phases.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuestionProgressView(
                total: viewModel.questions.count,
                current: min(viewModel.questionIndex + 1, viewModel.questions.count)
            )

            HStack {
                Text(viewModel.phase.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.snappy) {
                        showDemoControls.toggle()
                    }
                } label: {
                    Label("Demo Controls", systemImage: showDemoControls ? "chevron.down" : "chevron.up")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            if showDemoControls {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prototype only: jump between simulated states.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(InterviewPhase.allCases) { phase in
                            Button(phase.rawValue.capitalized) {
                                viewModel.setPhaseForDemo(phase)
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.phase == phase ? .accentColor : .secondary)
                        }
                        Button("Next Q") {
                            viewModel.moveToNextQuestionForDemo()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(12)
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(.separator).opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

#Preview {
    let viewModel = InterviewSessionViewModel()
    viewModel.jobProfile = MockHirelogueData.jobProfile
    viewModel.startInterview()
    return NavigationStack {
        InterviewSessionView(viewModel: viewModel, onShowFeedback: {}, onGoHome: {})
    }
}
