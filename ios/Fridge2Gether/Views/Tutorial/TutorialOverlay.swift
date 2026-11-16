import SwiftUI

// MARK: - Targets

/// Parts of the home screen the first-run tutorial points at.
enum TutorialTarget: Hashable {
    case camera, fridge, recipes, chat
}

/// One tutorial step: what to highlight and what to say about it.
struct TutorialStep {
    let target: TutorialTarget
    let icon: String
    let title: String
    let text: String

    /// Same order as the Week 8 doc: Camera, Ingredient Management, Recipes, Chat.
    static let all: [TutorialStep] = [
        TutorialStep(
            target: .camera, icon: "camera",
            title: "Add food with a photo",
            text: "Tap the camera and take a photo of your groceries. Lay them out so each item is clearly visible. The app finds each food, its amount and expiry date, and you can check and edit everything before saving."
        ),
        TutorialStep(
            target: .fridge, icon: "refrigerator",
            title: "Manage your ingredients",
            text: "Personal is food just for you. Shared is food your roommates can use too. Tap any food to update how much is left, change its expiry date or who it's shared with. A yellow or red ring means it expires soon."
        ),
        TutorialStep(
            target: .recipes, icon: "frying.pan",
            title: "Get recipe ideas",
            text: "Recipes are made from what's in your fridge, using food that expires soonest first. You can also pick the ingredients you want to cook with today."
        ),
        TutorialStep(
            target: .chat, icon: "bubble.left.and.bubble.right.fill",
            title: "Chat with your roommates",
            text: "Everyone who shares this fridge is in one chat. Ask for food, offer food you won't finish, and see when shared food is added or used up."
        ),
    ]
}

/// Records where a tutorial target is on screen.
private struct TutorialTargetModifier: ViewModifier {
    @Environment(AppStore.self) private var store
    let target: TutorialTarget

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                Color.clear
                    .onAppear { store.setTutorialFrame(frame, for: target) }
                    .onChange(of: frame) { store.setTutorialFrame(frame, for: target) }
            }
        }
    }
}

extension View {
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        modifier(TutorialTargetModifier(target: target))
    }
}

// MARK: - Overlay

/// Dims the screen, cuts a hole around the current target and shows a tip card next to it.
struct TutorialOverlay: View {
    @Environment(AppStore.self) private var store
    @State private var index = 0

    private var step: TutorialStep { TutorialStep.all[index] }
    private var isLast: Bool { index == TutorialStep.all.count - 1 }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let hole = store.tutorialFrames[step.target]
                .map { $0.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -8, dy: -8) }
            ZStack {
                Spotlight(hole: hole)
                    .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: next)
                    .animation(.easeInOut(duration: 0.3), value: index)

                if let hole {
                    Spotlight(hole: hole, outlineOnly: true)
                        .stroke(Palette.yellow, lineWidth: 3)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.3), value: index)
                }

                card(in: geo.size, hole: hole)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    /// Card goes on whichever side of the highlight has more room.
    @ViewBuilder
    private func card(in size: CGSize, hole: CGRect?) -> some View {
        let spaceAbove = hole?.minY ?? size.height / 2
        let spaceBelow = size.height - (hole?.maxY ?? size.height / 2)
        let above = spaceAbove > spaceBelow
        VStack(spacing: 0) {
            if above {
                Spacer(minLength: 54)
                tipCard
                Spacer().frame(height: max(size.height - spaceAbove + 14, 0))
            } else {
                Spacer().frame(height: max(size.height - spaceBelow + 14, 0))
                tipCard
                Spacer(minLength: 30)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.spring(duration: 0.35), value: index)
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: step.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Palette.mint))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 1) {
                    Text("TIP \(index + 1) OF \(TutorialStep.all.count)").eyebrowStyle()
                    Text(step.title).font(AppFont.rounded(18, .black))
                }
            }
            Text(step.text)
                .font(AppFont.rounded(14, .semibold))
                .foregroundStyle(Color(hex: 0x4F6560))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if !isLast {
                    Button("Skip", action: finish)
                        .font(AppFont.rounded(13, .black))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button(isLast ? "Got it" : "Next", action: next)
                    .font(AppFont.rounded(14, .black))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.yellow))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink, lineWidth: 2))
            }
            .padding(.top, 2)
        }
        .foregroundStyle(Palette.ink)
        .padding(16)
        .cartoonCard(radius: 20)
        .padding(.horizontal, 22)
        .id(index)
        .transition(.opacity)
    }

    private func next() {
        if isLast {
            finish()
        } else {
            withAnimation { index += 1 }
        }
    }

    private func finish() {
        withAnimation { store.finishTutorial() }
    }
}

/// Full-screen rectangle with a rounded hole (even-odd fill), or just the hole's outline.
private struct Spotlight: Shape {
    var hole: CGRect?
    var outlineOnly = false

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            let r = hole ?? .zero
            return AnimatablePair(AnimatablePair(r.minX, r.minY), AnimatablePair(r.width, r.height))
        }
        set {
            guard hole != nil else { return }
            hole = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first, height: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if !outlineOnly { path.addRect(rect) }
        if let hole {
            let radius = min(22, min(hole.width, hole.height) / 2)
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }
}
