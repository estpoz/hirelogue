import SwiftUI

/// Root coordinator for app-wide session state and NavigationStack routing.
struct ContentView: View {
    // MARK: - State

    /// Shared MVVM source of truth passed into each screen.
    @State private var viewModel = InterviewSessionViewModel()

    /// Stack path for the single linear interview flow.
    @State private var path: [AppRoute] = []

    /// Controls the custom animated splash overlay shown on launch.
    @State private var isShowingSplash = true

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                HomeJobInputView(viewModel: viewModel) {
                    path = [.setup]
                }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .setup:
                        InterviewSetupView(
                            viewModel: viewModel,
                            onStartInterview: { path.append(.session) },
                            onGoHome: { path = [] }
                        )
                    case .session:
                        InterviewSessionView(
                            viewModel: viewModel,
                            onShowFeedback: { showFeedback() },
                            onReturnToSetup: { path = [.setup] },
                            onGoHome: { path = [] }
                        )
                    case .feedback:
                        InterviewFeedbackView(
                            viewModel: viewModel,
                            onPractiseAgain: { path = [.setup] },
                            onBackToHome: { path = [] }
                        )
                    }
                }
            }

            if isShowingSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                isShowingSplash = false
            }
        }
    }

    // MARK: - Navigation Helpers

    /// Pushes feedback once, even if the mock finish signal fires more than once.
    private func showFeedback() {
        guard path.last != .feedback else { return }
        path.append(.feedback)
    }
}

#Preview {
    ContentView()
}
