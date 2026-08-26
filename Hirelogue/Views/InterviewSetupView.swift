import SwiftUI

/// Lets the user review the mock job profile and configure the practice interview.
struct InterviewSetupView: View {
    // MARK: - Dependencies

    @Bindable var viewModel: InterviewSessionViewModel

    /// Called after microphone permission is granted and the mock session starts.
    let onStartInterview: () -> Void

    /// Called when setup is opened without a prepared job profile.
    let onGoHome: () -> Void

    // MARK: - Local UI State

    @State private var isEditingProfile = false
    @State private var isMicrophoneDeniedAlertPresented = false
    @State private var draftPosition = ""
    @State private var draftSeniority = ""
    @State private var editingListSection: EditableListSection?
    @State private var draftListText = ""

    // MARK: - Body

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

                            GroupedCard(
                                "Key responsibilities",
                                trailing: AnyView(editButton(for: .responsibilities, profile: profile))
                            ) {
                                BulletListView(items: profile.responsibilities)
                            }

                            GroupedCard(
                                "Required qualifications",
                                trailing: AnyView(editButton(for: .requiredQualifications, profile: profile))
                            ) {
                                BulletListView(items: profile.requiredQualifications)
                            }

                            GroupedCard(
                                "Preferred qualifications",
                                trailing: AnyView(editButton(for: .preferredQualifications, profile: profile))
                            ) {
                                BulletListView(items: profile.preferredQualifications)
                            }

                            GroupedCard(
                                "Technical competencies",
                                footer: "Remove anything that does not apply to the role you are practising for.",
                                trailing: AnyView(editButton(for: .technicalCompetencies, profile: profile))
                            ) {
                                TagCloud(tags: profile.technicalCompetencies) { tag in
                                    viewModel.removeTechnicalCompetency(tag)
                                }
                            }

                            GroupedCard(
                                "Behavioral competencies",
                                trailing: AnyView(editButton(for: .behavioralCompetencies, profile: profile))
                            ) {
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
                .sheet(item: $editingListSection) { section in
                    editListSheet(for: section)
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

    // MARK: - Configuration Sections

    /// Segmented selector for the style of questions to ask.
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

    /// Duration picker rendered as native tappable rows.
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

    private func editButton(for section: EditableListSection, profile: JobProfile) -> some View {
        Button("Edit") {
            openListEditor(for: section, profile: profile)
        }
        .font(.subheadline.weight(.semibold))
    }

    // MARK: - Edit Profile Sheet

    /// Small editing surface for the two top-level profile fields.
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

    private func editListSheet(for section: EditableListSection) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draftListText)
                        .font(.body)
                        .frame(minHeight: 220)
                        .accessibilityLabel(section.title)
                } footer: {
                    Text("Enter one item per line.")
                }

                Section {
                    Button("Save Changes") {
                        saveListEditor(for: section)
                    }
                }
            }
            .navigationTitle("Edit \(section.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingListSection = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    /// Seeds the sheet with the current profile values before presenting it.
    private func openEditor(with profile: JobProfile) {
        draftPosition = profile.position
        draftSeniority = profile.seniority
        isEditingProfile = true
    }

    private func openListEditor(for section: EditableListSection, profile: JobProfile) {
        draftListText = section.items(in: profile).joined(separator: "\n")
        editingListSection = section
    }

    private func saveListEditor(for section: EditableListSection) {
        let items = draftListText.components(separatedBy: .newlines)
        viewModel.updateProfileList(section.keyPath, items: items)
        editingListSection = nil
    }

    /// Gates the interview behind system microphone permission.
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

private enum EditableListSection: String, Identifiable {
    case responsibilities
    case requiredQualifications
    case preferredQualifications
    case technicalCompetencies
    case behavioralCompetencies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .responsibilities:
            return "Key Responsibilities"
        case .requiredQualifications:
            return "Required Qualifications"
        case .preferredQualifications:
            return "Preferred Qualifications"
        case .technicalCompetencies:
            return "Technical Competencies"
        case .behavioralCompetencies:
            return "Behavioral Competencies"
        }
    }

    var keyPath: WritableKeyPath<JobProfile, [String]> {
        switch self {
        case .responsibilities:
            return \.responsibilities
        case .requiredQualifications:
            return \.requiredQualifications
        case .preferredQualifications:
            return \.preferredQualifications
        case .technicalCompetencies:
            return \.technicalCompetencies
        case .behavioralCompetencies:
            return \.behavioralCompetencies
        }
    }

    func items(in profile: JobProfile) -> [String] {
        profile[keyPath: keyPath]
    }
}

#Preview {
    let viewModel = InterviewSessionViewModel()
    viewModel.jobProfile = MockHirelogueData.jobProfile
    return NavigationStack {
        InterviewSetupView(viewModel: viewModel, onStartInterview: {}, onGoHome: {})
    }
}
