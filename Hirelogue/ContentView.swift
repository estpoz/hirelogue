import SwiftUI

struct ContentView: View {
    @State private var viewModel = InterviewSessionViewModel()
    @State private var path: [AppRoute] = []
    @State private var isShowingSplash = true

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

    private func showFeedback() {
        guard path.last != .feedback else { return }
        path.append(.feedback)
    }
}

#Preview {
    ContentView()
}
