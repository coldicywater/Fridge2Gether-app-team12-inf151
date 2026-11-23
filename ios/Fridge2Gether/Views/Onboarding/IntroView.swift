import SwiftUI

/// First thing a new user sees: what the app is for, before making an account.
/// Three pages: manage ingredients, track expiry dates, waste less together.
struct IntroView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: String
        let tint: Color
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(icon: "refrigerator", tint: Palette.fridgeBlue,
             title: "Your fridge, on your phone",
             text: "See everything you have at a glance."),
        Page(icon: "calendar.badge.clock", tint: Color(hex: 0xFCE3A3),
             title: "Know what expires next",
             text: "Get a reminder before food goes bad."),
        Page(icon: "leaf", tint: Palette.mint,
             title: "Waste less, together",
             text: "Share food and recipes with your roommates."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xDFF1E9), Color(hex: 0xF9F4E8)], startPoint: .topLeading, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button("Skip", action: onDone)
                            .font(AppFont.rounded(14, .black))
                            .foregroundStyle(Color(hex: 0x367D64))
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 22)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Palette.ink : Palette.ink.opacity(0.2))
                            .frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.25), value: page)
                .padding(.bottom, 22)

                Button(isLast ? "Get started" : "Next") {
                    if isLast { onDone() } else { withAnimation { page += 1 } }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
        .foregroundStyle(Palette.ink)
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: item.icon)
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Color(hex: 0x2E765E))
                .frame(width: 150, height: 150)
                .background(RoundedRectangle(cornerRadius: 56).fill(item.tint))
                .overlay(RoundedRectangle(cornerRadius: 56).stroke(Palette.ink, lineWidth: 3))
                .background(RoundedRectangle(cornerRadius: 56).fill(Palette.ink).offset(x: 5, y: 6))
                .rotationEffect(.degrees(-3))
                .padding(.bottom, 44)
            Text(item.title)
                .font(AppFont.rounded(28, .black))
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)
            Text(item.text)
                .font(AppFont.rounded(15, .semibold))
                .foregroundStyle(Color(hex: 0x5F7570))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// Xcode canvas: Editor → Canvas (⌥⌘↩). Updates as you edit; no phone or sign-in needed.
#Preview("Intro pages") {
    IntroView(onDone: {})
}
