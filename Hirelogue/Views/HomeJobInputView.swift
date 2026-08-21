import SwiftUI

struct HomeJobInputView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: InterviewSessionViewModel
    let onAnalysisComplete: () -> Void

    var body: some View {
        ScreenContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Practise for your next interview")
                                .font(.largeTitle.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Paste a job opening and practise answering questions tailored to its responsibilities and qualifications.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)

                        jobOpeningEditor

                        Text("Hirelogue is a practice tool. It does not evaluate your chances of being hired.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }

                BottomActionArea {
                    Button {
                        viewModel.analyzeJobOpening(onComplete: onAnalysisComplete)
                    } label: {
                        if viewModel.isAnalyzing {
                            Label("Analyzing...", systemImage: "hourglass")
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Analyze Job Opening")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canAnalyze)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(colorScheme == .dark ? "darkLogoTextOnly" : "logoTextOnly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 24)
                        .accessibilityLabel("Hirelogue")
                }
            }
            .overlay {
                if viewModel.isAnalyzing {
                    analyzingOverlay
                }
            }
        }
    }

    private var jobOpeningEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .lastTextBaseline) {
                Text("Job opening")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button("Use Example") {
                    viewModel.useExampleJobOpening()
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 4)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(.separator).opacity(0.45), lineWidth: 0.5)
                    }

                TextEditor(text: $viewModel.jobOpening)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 260)
                    .accessibilityLabel("Job opening")

                if viewModel.jobOpening.isEmpty {
                    Text("Paste the complete job description, responsibilities, and qualifications here.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            Text("The job opening will be analyzed with mock data for this app-base milestone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView(value: viewModel.analysisProgress)
                    .progressViewStyle(.linear)
                Text("Analyzing job opening...")
                    .font(.headline)
                Text("Identifying the role, qualifications, and interview competencies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(24)
        }
    }
}

#Preview {
    NavigationStack {
        HomeJobInputView(viewModel: InterviewSessionViewModel()) {}
    }
}
