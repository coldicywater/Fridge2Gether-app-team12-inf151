import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.phase {
        case .loading:
            ZStack {
                ScreenBackground()
                VStack(spacing: 16) {
                    FridgeDoodle()
                    ProgressView().tint(Palette.ink)
                }
            }
        case .missingFirebaseConfig:
            SetupMessageView(
                title: "Firebase isn't set up yet",
                message: "Add GoogleService-Info.plist to the Fridge2Gether folder in Xcode, then run the app again. The README has the steps."
            )
        case .error(let message):
            SetupMessageView(title: "Something went wrong", message: message) {
                Task { await store.retry() }
            }
        case .onboarding:
            OnboardingView()
        case .ready:
            MainView()
        }
    }
}

struct SetupMessageView: View {
    let title: String
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 18) {
                FridgeDoodle()
                Text(title)
                    .font(AppFont.rounded(24, .black))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(AppFont.rounded(14, .semibold))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                if let retry {
                    Button("Try again", action: retry)
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(width: 200)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(28)
        }
    }
}

/// The tilted blue fridge badge from the onboarding screens.
struct FridgeDoodle: View {
    var label: String? = "fresh start"
    var size: CGFloat = 105

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "refrigerator")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(Color(hex: 0x2E765E))
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.42).fill(Palette.fridgeBlue))
                .overlay(RoundedRectangle(cornerRadius: size * 0.42).stroke(Palette.ink, lineWidth: 3))
                .background(RoundedRectangle(cornerRadius: size * 0.42).fill(Palette.ink).offset(x: 5, y: 6))
            if let label {
                Text(label)
                    .font(AppFont.hand(16))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Palette.yellow))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Palette.ink, lineWidth: 2))
                    .rotationEffect(.degrees(7))
                    .offset(x: 34, y: 8)
            }
        }
        .rotationEffect(.degrees(-3))
    }
}
