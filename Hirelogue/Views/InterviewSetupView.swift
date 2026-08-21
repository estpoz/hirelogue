import SwiftUI

struct InterviewSetupView: View {
    @Bindable var viewModel: InterviewSessionViewModel
    let onStartInterview: () -> Void
    let onGoHome: () -> Void

    @State private var isEditingProfile = false
    @State private var isMicrophoneDeniedAlertPresented = false
    @State private var draftPosition = ""
    @State private var draftSeniority = ""

    var body: some View {
        ScreenContainer {
            if let profile = viewModel.jobProfile {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 22) {
                            Text("Review the extracted information before starting. Your interview will be based on this profile.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                            GroupedCard(
                                "Job profile",
                                trailing: AnyView(Button("Edit") { openEditor(with: profile) }.font(.subheadline.weight(.semibold)))
                            ) {
                                InfoRow(label: "Position", value: profile.position)
                                Divider().padding(.leading, 16)
                                InfoRow(label: "Seniority", value: profile.seniority)
                            }

                            GroupedCard("Key responsibilities") {
                                BulletListView(items: profile.responsibilities)
                            }

                            GroupedCard("Required qualifications") {
                                BulletListView(items: profile.requiredQualifications)
                            }

                            GroupedCard("Preferred qualifications") {
                                BulletListView(items: profile.preferredQualifications)
                            }

                            GroupedCard("Technical competencies", footer: "Remove anything that does not apply to the role you are practising for.") {
                                TagCloud(tags: profile.technicalCompetencies) { tag in
                                    viewModel.removeTechnicalCompetency(tag)
                                }
                            }

                            GroupedCard("Behavioral competencies") {
                                TagCloud(tags: profile.behavioralCompetencies, muted: true) { tag in
                                    viewModel.removeBehavioralCompetency(tag)
                                }
                            }

                            interviewTypeSection
                            durationSection
                        }
                        .padding(.bottom, 20)
                    }

                    BottomActionArea {
                        Button {
                            Task {
                                await startInterviewAfterPermission()
                            }
                        } label: {
                            if viewModel.isRequestingMicrophonePermission {
                                Label("Requesting Microphone...", systemImage: "mic.circle")
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Start Interview", systemImage: "mic.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isRequestingMicrophonePermission)
                    }
                }
                .navigationTitle("Interview Setup")
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $isEditingProfile) {
                    editProfileSheet
                }
                .alert("Microphone Access Needed", isPresented: $isMicrophoneDeniedAlertPresented) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Hirelogue needs microphone access before starting a voice interview. You can enable it later in Settings.")
                }
            } else {
                EmptyStateView(
                    title: "No job profile yet",
                    message: "Paste a job opening on the home screen to prepare an interview.",
                    actionTitle: "Go to Home",
                    action: onGoHome
                )
                .navigationTitle("Interview Setup")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var interviewTypeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Interview type")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
            Picker("Interview type", selection: $viewModel.interviewType) {
                ForEach(InterviewType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
    }

    private var durationSection: some View {
        GroupedCard("Interview duration") {
            ForEach(Array(InterviewDuration.allCases.enumerated()), id: \.element.id) { index, duration in
                Button {
                    viewModel.duration = duration
                } label: {
                    HStack {
                        Text(duration.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.duration == duration {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)

                if index < InterviewDuration.allCases.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
    }

    private var editProfileSheet: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    TextField("Position", text: $draftPosition)
                }
                Section("Seniority") {
                    TextField("Seniority", text: $draftSeniority)
                }
                Section {
                    Button("Save Changes") {
                        viewModel.updateProfile(position: draftPosition, seniority: draftSeniority)
                        isEditingProfile = false
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditingProfile = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func openEditor(with profile: JobProfile) {
        draftPosition = profile.position
        draftSeniority = profile.seniority
        isEditingProfile = true
    }

    private func startInterviewAfterPermission() async {
        let isGranted = await viewModel.requestMicrophonePermission()
        guard isGranted else {
            isMicrophoneDeniedAlertPresented = true
            return
        }

        viewModel.startInterview()
        onStartInterview()
    }
}

#Preview {
    let viewModel = InterviewSessionViewModel()
    viewModel.jobProfile = MockHirelogueData.jobProfile
    return NavigationStack {
        InterviewSetupView(viewModel: viewModel, onStartInterview: {}, onGoHome: {})
    }
}
