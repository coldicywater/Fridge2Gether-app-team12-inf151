import SwiftUI

// MARK: - Tours

/// One short guided tour per screen. Each plays the first time you open that screen.
/// "Show app tutorial" in the profile resets them all.
enum Tour: String, CaseIterable {
    case home, detail, camera, review, recipes, chat, profile

    var seenKey: String { "tourSeen.\(rawValue)" }

    var steps: [TutorialStep] {
        switch self {
        case .home: return [
            TutorialStep(.personalShelf, "Personal", "Food only you can see."),
            TutorialStep(.sharedShelf, "Shared", "Food your roommates can use too."),
            TutorialStep(.food, "Tap a food", "Update how much is left, the expiry date, or sharing."),
            TutorialStep(.expiringBanner, "Expiring soon", "Yellow and red rings mean eat it soon. Tap to see them all."),
            TutorialStep(.camera, "Add food", "Take a photo of your groceries. AI fills in the details."),
            TutorialStep(.recipes, "Recipes", "Ideas made from what's in your fridge."),
            TutorialStep(.chat, "Fridge chat", "Talk with everyone who shares this fridge."),
            TutorialStep(.profile, "Your fridge crew", "Invite roommates and switch fridges here."),
        ]
        case .detail: return [
            TutorialStep(.detailQuantity, "Used some?", "Tap here to update how much is left."),
            TutorialStep(.detailExpiry, "Wrong date?", "Tap here to change the expiry date."),
            TutorialStep(.detailUsedUp, "Finished it?", "Used Up takes it out of the fridge."),
            TutorialStep(.detailShare, "Sharing", "Choose which roommates can use it."),
            TutorialStep(.detailCook, "Cook it", "Get recipes that use this food."),
        ]
        case .camera: return [
            TutorialStep(.cameraShutter, "Take a photo", "Spread your food out so each item is clearly visible."),
            TutorialStep(.cameraLibrary, "Or use a photo", "Pick a picture you already took."),
        ]
        case .review: return [
            TutorialStep(.reviewStickers, "Found items", "Tap a sticker to edit that food."),
            TutorialStep(.reviewQuantity, "Amount", "Use − and + and pick a unit, like 2 apples."),
            TutorialStep(.reviewExpiry, "Expiry date", "AI guesses it. Change it if needed."),
            TutorialStep(.reviewSharing, "Who can use it", "Just Me, Everyone, or picked roommates."),
            TutorialStep(.reviewAdd, "Save", "Adds everything to your fridge."),
        ]
        case .recipes: return [
            TutorialStep(.recipePick, "Pick ingredients", "Tap foods you want to cook with, then Make recipes."),
            TutorialStep(.recipeCard, "Open a recipe", "See the steps. When you're done, update what's left."),
            TutorialStep(.recipeRefresh, "New ideas", "Get a fresh set of recipes."),
        ]
        case .chat: return [
            TutorialStep(.chatPlus, "Ask or offer", "Ask roommates for food, or give yours away."),
            TutorialStep(.chatInput, "Message", "Everyone in this fridge sees it."),
        ]
        case .profile: return [
            TutorialStep(.profileInvite, "Invite roommates", "Send this code. They join with it to share your fridge."),
            TutorialStep(.profileFridges, "Your fridges", "Switch fridges, join another with a code, or start a new one."),
        ]
        }
    }
}

/// Parts of the app the tours point at.
enum TutorialTarget: Hashable {
    // Home
    case personalShelf, sharedShelf, food, expiringBanner, camera, recipes, chat, profile
    // Food detail
    case detailQuantity, detailExpiry, detailUsedUp, detailShare, detailCook
    // Scan
    case cameraShutter, cameraLibrary
    case reviewStickers, reviewQuantity, reviewExpiry, reviewSharing, reviewAdd
    // Recipes
    case recipePick, recipeCard, recipeRefresh
    // Chat
    case chatPlus, chatInput
    // Profile
    case profileInvite, profileFridges
}

struct TutorialStep {
    let target: TutorialTarget
    let title: String
    let text: String

    init(_ target: TutorialTarget, _ title: String, _ text: String) {
        self.target = target
        self.title = title
        self.text = text
    }
}

/// Where a target is on screen. `owner` lets two copies of the same target
/// (the chat button on Home and on Recipes) come and go without erasing each other.
struct TargetFrame: Equatable {
    let owner: UUID
    let rect: CGRect
}

private struct TutorialTargetModifier: ViewModifier {
    @Environment(AppStore.self) private var store
    let target: TutorialTarget
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                Color.clear
                    .onAppear { store.setTutorialFrame(frame, for: target, owner: owner) }
                    .onChange(of: frame) { store.setTutorialFrame(frame, for: target, owner: owner) }
                    .onDisappear { store.clearTutorialFrame(for: target, owner: owner) }
            }
        }
    }
}

extension View {
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        modifier(TutorialTargetModifier(target: target))
    }

    /// Starts `tour` the first time this screen shows and draws it on top.
    func tour(_ tour: Tour) -> some View {
        modifier(TourHost(tour: tour))
    }
}

private struct TourHost: ViewModifier {
    @Environment(AppStore.self) private var store
    let tour: Tour

    func body(content: Content) -> some View {
        content
            .overlay {
                if store.activeTour == tour {
                    TutorialOverlay(tour: tour)
                }
            }
            .onAppear { store.startTour(tour) }
            .onDisappear { store.cancelTour(tour) }
    }
}

// MARK: - Overlay

/// Dims the screen, cuts a hole around the current target and shows a short tip next to it.
/// Steps whose target isn't on screen (no roommates, empty fridge, below the fold) are skipped.
struct TutorialOverlay: View {
    @Environment(AppStore.self) private var store
    let tour: Tour
    @State private var steps: [TutorialStep] = []
    @State private var index = 0

    var body: some View {
        GeometryReader { geo in
            let bounds = geo.frame(in: .global)
            ZStack {
                if steps.indices.contains(index) {
                    let step = steps[index]
                    let hole = store.tutorialFrames[step.target]
                        .map { $0.rect.offsetBy(dx: -bounds.minX, dy: -bounds.minY).insetBy(dx: -7, dy: -7) }
                    Spotlight(hole: hole)
                        .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                        .contentShape(Rectangle())
                        .onTapGesture(perform: next)
                    if let hole {
                        Spotlight(hole: hole, outlineOnly: true)
                            .stroke(Palette.yellow, lineWidth: 3)
                            .allowsHitTesting(false)
                    }
                    card(step, in: geo.size, hole: hole)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: index)
            .onAppear { steps = visibleSteps(in: bounds) }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    private func visibleSteps(in bounds: CGRect) -> [TutorialStep] {
        let found = tour.steps.filter { step in
            guard let rect = store.tutorialFrames[step.target]?.rect, rect.width > 1, rect.height > 1 else { return false }
            let shown = rect.intersection(bounds)
            return !shown.isNull && shown.height >= rect.height * 0.6
        }
        if found.isEmpty { DispatchQueue.main.async { store.finishTour(tour) } }
        return found
    }

    /// Card sits on whichever side of the highlight has more room.
    @ViewBuilder
    private func card(_ step: TutorialStep, in size: CGSize, hole: CGRect?) -> some View {
        let spaceAbove = hole?.minY ?? size.height / 2
        let spaceBelow = size.height - (hole?.maxY ?? size.height / 2)
        VStack(spacing: 0) {
            if spaceAbove > spaceBelow {
                Spacer(minLength: 54)
                tipCard(step)
                Spacer().frame(height: max(size.height - spaceAbove + 12, 0))
            } else {
                Spacer().frame(height: max(size.height - spaceBelow + 12, 0))
                tipCard(step)
                Spacer(minLength: 30)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func tipCard(_ step: TutorialStep) -> some View {
        let isLast = index == steps.count - 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(step.title).font(AppFont.rounded(17, .black))
                Spacer()
                Text("\(index + 1)/\(steps.count)")
                    .font(AppFont.rounded(11, .black))
                    .foregroundStyle(Palette.muted)
            }
            Text(step.text)
                .font(AppFont.rounded(14, .semibold))
                .foregroundStyle(Color(hex: 0x4F6560))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if !isLast {
                    Button("Skip") { store.finishTour(tour) }
                        .font(AppFont.rounded(13, .black))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button(isLast ? "Got it" : "Next", action: next)
                    .font(AppFont.rounded(14, .black))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.yellow))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink, lineWidth: 2))
            }
            .padding(.top, 4)
        }
        .foregroundStyle(Palette.ink)
        .padding(14)
        .cartoonCard(radius: 18)
        .padding(.horizontal, 26)
        .id(index)
        .transition(.opacity)
    }

    private func next() {
        if index >= steps.count - 1 {
            store.finishTour(tour)
        } else {
            index += 1
        }
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
            let radius = min(20, min(hole.width, hole.height) / 2)
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }
}
