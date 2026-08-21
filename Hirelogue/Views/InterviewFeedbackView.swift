import SwiftUI

struct InterviewFeedbackView: View {
    @Bindable var viewModel: InterviewSessionViewModel
    let onPractiseAgain: () -> Void
    let onBackToHome: () -> Void

    var body: some View {
        ScreenContainer {
            if let profile = viewModel.jobProfile {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            summaryCard(profile: profile)
                            competenciesCard
                            strengthsCard
                            improvementsCard
                            starCard
                            technicalReasoningCard
                            improvedAnswerCard
                            practiceAreasCard

                            Text("Practice feedback only. Hirelogue does not predict hiring outcomes.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 18)
                    }

                    BottomActionArea {
                        Button {
                            viewModel.practiseAgain()
                            onPractiseAgain()
                        } label: {
                            Label("Practise Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            viewModel.resetToHome()
                            onBackToHome()
                        } label: {
                            Text("Back to Home")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .navigationTitle("Your Feedback")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyStateView(
                    title: "No session to review",
                    message: "Complete a practice interview to see feedback here.",
                    actionTitle: "Go to Home",
                    action: onBackToHome
                )
                .navigationTitle("Your Feedback")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func summaryCard(profile: JobProfile) -> some View {
        FeedbackCard("Interview Complete") {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.green)
                Text(profile.position)
                    .font(.headline)
                Text("\(viewModel.interviewType.rawValue) - \(viewModel.duration.title) - \(profile.seniority)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Divider()
                Text(viewModel.feedback.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var competenciesCard: some View {
        FeedbackCard("Competencies assessed", caption: "Based on the job profile and what your answers covered.") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Technical")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                AssessmentTagCloud(assessments: viewModel.feedback.technicalCompetencies)
                Text("Behavioral")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 4)
                AssessmentTagCloud(assessments: viewModel.feedback.behavioralCompetencies)
            }
        }
    }

    private var strengthsCard: some View {
        FeedbackCard("Strengths demonstrated") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.feedback.strengths) { point in
                    FeedbackPointRow(point: point, symbol: "checkmark.circle.fill", tint: .green)
                }
            }
        }
    }

    private var improvementsCard: some View {
        FeedbackCard("Areas to improve") {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.feedback.improvements) { point in
                    FeedbackPointRow(point: point, symbol: "exclamationmark.circle.fill", tint: .orange)
                }
            }
        }
    }

    private var starCard: some View {
        FeedbackCard("Answer structure", caption: "Behavioral question: \(viewModel.feedback.starQuestion)") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.feedback.starAssessments) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.present ? "checkmark.circle.fill" : "minus.circle.fill")
                            .foregroundStyle(item.present ? .green : .orange)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.present ? "Present" : "Needs improvement")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var technicalReasoningCard: some View {
        FeedbackCard("Technical reasoning", caption: "How clearly you explained your technical decisions.") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(viewModel.feedback.technicalReasoning, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                        Text(line)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var improvedAnswerCard: some View {
        FeedbackCard("Suggested improvement", caption: "Example formulation - \(viewModel.feedback.improvedAnswerQuestion)") {
            VStack(alignment: .leading, spacing: 8) {
                Text("One possible stronger answer")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(viewModel.feedback.improvedAnswer)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("This is an example of structure, not an answer to memorise. Use your own experience.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var practiceAreasCard: some View {
        FeedbackCard("Recommended practice areas") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.feedback.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor.opacity(0.12), in: Circle())
                        Text(recommendation)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

#Preview {
    let viewModel = InterviewSessionViewModel()
    viewModel.jobProfile = MockHirelogueData.jobProfile
    return NavigationStack {
        InterviewFeedbackView(viewModel: viewModel, onPractiseAgain: {}, onBackToHome: {})
    }
}
