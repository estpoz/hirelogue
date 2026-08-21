import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Image(colorScheme == .dark ? "darkLogoWithText" : "logoWithText")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260)
                .scaleEffect(isAnimating ? 1.0 : 0.94)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.7), value: isAnimating)
                .accessibilityLabel("Hirelogue")
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    SplashScreenView()
}
