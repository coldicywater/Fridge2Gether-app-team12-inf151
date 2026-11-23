import SwiftUI

// MARK: - The guided tour

/// One hands-on walkthrough across the whole app. The user actually does each thing:
/// takes a photo, edits it, saves it, sees it in the fridge, opens the chat and profile,
/// then picks ingredients, makes recipes and cooks one.
/// Steps with a `waitFor` event only move on when the user does that action;
/// the others have a Next button.
/// Plays once for new users; "Show app tutorial" in the profile plays it again.
enum Guide {
    static let doneKey = "guide.v2.done"

    static let steps: [GuideStep] = [
        // Add food
        GuideStep("Add food", .home, [.camera], "Add your first food",
                  "Tap the camera.", waitFor: .scanOpened),
        GuideStep("Add food", .camera, [.cameraShutter, .cameraLibrary], "Take a photo",
                  "Put a few groceries in view and tap the button. No camera? Pick a photo instead.", waitFor: .photoTaken),
        GuideStep("Add food", .review, [.reviewStickers], "AI found these",
                  "Each sticker is one food. Tap a sticker to edit it."),
        GuideStep("Add food", .review, [.reviewName], "Name",
                  "Fix the name if AI got it wrong."),
        GuideStep("Add food", .review, [.reviewQuantity], "Amount",
                  "Use − and +, and pick a word like apples or plates."),
        GuideStep("Add food", .review, [.reviewExpiry], "Expiry date",
                  "AI guesses it. Change it if you know better. You can also change it later."),
        GuideStep("Add food", .review, [.reviewSharing], "Who can use it",
                  "Just you, everyone, or roommates you pick."),
        GuideStep("Add food", .review, [.reviewAdd], "Add to your fridge",
                  "Tap to save.", waitFor: .foodsSaved),

        // Your fridge
        GuideStep("Your fridge", .home, [.food], "Here it is",
                  "Tap any food later to update how much is left or change its date.", showWithoutTarget: true),
        GuideStep("Your fridge", .home, [.food], "Ring colors",
                  "White: fresh.\nYellow: expires within 3 days.\nRed: eat it today or tomorrow.", showWithoutTarget: true),
        GuideStep("Your fridge", .home, [.personalShelf], "Personal",
                  "Food only you can see."),
        GuideStep("Your fridge", .home, [.sharedShelf], "Shared",
                  "Food your roommates can use too."),
        GuideStep("Your fridge", .home, [.expiringBanner], "Expiry reminders",
                  "We send a notification the morning before something expires. Food expiring soon also shows up here.",
                  showWithoutTarget: true),

        // Chat
        GuideStep("Chat", .home, [.chat], "Fridge chat",
                  "Tap to open the chat for this fridge.", waitFor: .chatOpened),
        GuideStep("Chat", .chat, [.chatPlus], "Ask or offer",
                  "Ask roommates for food, or give yours away."),
        GuideStep("Chat", .chat, [.chatInput], "Message",
                  "Everyone in this fridge sees it. Updates like \"Alex used up the milk\" show up here too."),
        GuideStep("Chat", .chat, [.chatClose], "Back to the fridge",
                  "Tap to close the chat.", waitFor: .chatClosed),

        // Roommates
        GuideStep("Roommates", .home, [.profile], "Your account",
                  "Tap to see your profile and roommates.", waitFor: .profileOpened),
        GuideStep("Roommates", .profile, [.profileInvite], "Share your fridge",
                  "Send this code to roommates. Once they join, your fridge gets a Shared shelf."),
        GuideStep("Roommates", .profile, [.profileFridges], "Your fridges",
                  "Switch fridges, or join a friend's with their code."),
        GuideStep("Roommates", .profile, [.profileClose], "All good",
                  "Tap to close.", waitFor: .profileClosed),

        // Recipes
        GuideStep("Recipes", .home, [.recipes], "Recipes",
                  "Tap Recipes.", waitFor: .recipesOpened),
        GuideStep("Recipes", .recipes, [.recipePick], "Pick ingredients",
                  "Tap the foods you want to cook with. Mix expiring and fresh ones.", waitFor: .foodPicked),
        GuideStep("Recipes", .recipes, [.recipeMake], "Make recipes",
                  "Tap when you're done picking. AI makes recipes that use all of them.", waitFor: .recipesMade),
        GuideStep("Recipes", .recipes, [.recipeCard], "Open a recipe",
                  "Tap it to see what you need and the steps.", waitFor: .recipeOpened),
        GuideStep("Recipes", .recipeDetail, [.recipeStart], "Start cooking",
                  "Tap when you're ready.", waitFor: .cookingStarted),
        GuideStep("Recipes", .cooking, [.cookingNext], "Follow along",
                  "One step at a time. Tap Next Step, and Finish Cooking at the end.", waitFor: .cookingFinished),
        GuideStep("Recipes", .update, [.updateSave], "What's left?",
                  "Set how much of each food is left, then save. Your fridge updates.", waitFor: .cookingDone),

        // Done
        GuideStep("Done", .home, [], "You're all set!",
                  "Watch this again any time from your profile.", showWithoutTarget: true),
    ]
}

/// Which screen a step is shown on.
enum GuideScreen {
    case home, camera, review, chat, profile, recipes, recipeDetail, cooking, update

    var isRecipeFlow: Bool { [.recipes, .recipeDetail, .cooking, .update].contains(self) }
}

/// Things the user does that move the tour along.
enum GuideEvent {
    case scanOpened, photoTaken, foodsSaved, scanClosed
    case chatOpened, chatClosed
    case profileOpened, profileClosed
    case recipesOpened, recipesLeft, foodPicked, recipesMade
    case recipeOpened, cookingStarted, cookingFinished, cookingDone, recipeListShown
}

struct GuideStep {
    let section: String
    let screen: GuideScreen
    /// The first one that's on screen gets highlighted.
    let targets: [TutorialTarget]
    let title: String
    let text: String
    /// nil: Next button. Otherwise the user has to do this.
    let waitFor: GuideEvent?
    /// Show the card in the middle when the target isn't on screen, instead of skipping the step.
    let showWithoutTarget: Bool

    init(_ section: String, _ screen: GuideScreen, _ targets: [TutorialTarget], _ title: String, _ text: String,
         waitFor: GuideEvent? = nil, showWithoutTarget: Bool = false) {
        self.section = section
        self.screen = screen
        self.targets = targets
        self.title = title
        self.text = text
        self.waitFor = waitFor
        self.showWithoutTarget = showWithoutTarget
    }
}

/// Parts of the app the tour points at.
enum TutorialTarget: Hashable {
    // Home
    case personalShelf, sharedShelf, food, expiringBanner, camera, recipes, chat, profile
    // Food detail
    case detailQuantity, detailExpiry, detailUsedUp, detailShare, detailCook
    // Scan
    case cameraShutter, cameraLibrary
    case reviewStickers, reviewName, reviewQuantity, reviewExpiry, reviewSharing, reviewAdd
    // Recipes
    case recipePick, recipeMake, recipeCard, recipeRefresh, recipeStart, cookingNext, updateSave
    // Chat
    case chatPlus, chatInput, chatClose
    // Profile
    case profileInvite, profileFridges, profileClose
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
        content
            .background {
                GeometryReader { geo in
                    let frame = geo.frame(in: .global)
                    Color.clear
                        .onAppear { store.setTutorialFrame(frame, for: target, owner: owner) }
                        .onChange(of: frame) { store.setTutorialFrame(frame, for: target, owner: owner) }
                        .onDisappear { store.clearTutorialFrame(for: target, owner: owner) }
                }
            }
            // Lets the screen scroll to it (see guideAutoScroll).
            .id(target)
    }
}

extension View {
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        modifier(TutorialTargetModifier(target: target))
    }

    /// Draws the tour on top of this screen when the current step belongs to it.
    func guideHost(_ screen: GuideScreen) -> some View {
        modifier(GuideHost(screen: screen))
    }

    /// Scrolls the highlighted part into view. Put it on a ScrollView inside a ScrollViewReader.
    func guideAutoScroll(_ proxy: ScrollViewProxy) -> some View {
        modifier(GuideAutoScroll(proxy: proxy))
    }
}

private struct GuideHost: ViewModifier {
    @Environment(AppStore.self) private var store
    let screen: GuideScreen

    func body(content: Content) -> some View {
        content.overlay {
            if let index = store.guideIndex, let step = store.guideStep, step.screen == screen {
                GuideOverlay(step: step, index: index)
                    .id(index)
                    .transition(.opacity)
            }
        }
    }
}

private struct GuideAutoScroll: ViewModifier {
    @Environment(AppStore.self) private var store
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onAppear(perform: scroll)
            .onChange(of: store.guideIndex) { scroll() }
    }

    private func scroll() {
        guard let targets = store.guideStep?.targets, !targets.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.35)) {
                for target in targets { proxy.scrollTo(target, anchor: .center) }
            }
        }
    }
}

// MARK: - Overlay

/// Dims the screen, cuts a hole around the target and shows a short tip next to it.
/// On "do it" steps the dimmed area lets touches through, so the user can tap the real button (and scroll).
private struct GuideOverlay: View {
    @Environment(AppStore.self) private var store
    let step: GuideStep
    let index: Int

    private var sectionSteps: [Int] {
        Guide.steps.indices.filter { Guide.steps[$0].section == step.section }
    }

    var body: some View {
        GeometryReader { geo in
            let bounds = geo.frame(in: .global)
            let hole = store.guideTarget
                .flatMap { store.tutorialFrames[$0]?.rect }
                .map { $0.offsetBy(dx: -bounds.minX, dy: -bounds.minY).insetBy(dx: -7, dy: -7) }
            ZStack {
                if hole != nil || step.showWithoutTarget {
                    dim(hole)
                    if let hole {
                        Spotlight(hole: hole, outlineOnly: true)
                            .stroke(Palette.yellow, lineWidth: 3)
                            .allowsHitTesting(false)
                    }
                    card(in: geo.size, hole: hole)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: hole)
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        // A Next step whose target isn't there (no roommates, nothing expiring) is skipped.
        // "Do it" steps wait instead, e.g. for recipes to finish loading.
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            guard store.guideIndex == index, step.waitFor == nil, !step.showWithoutTarget else { return }
            let found = store.guideTarget.flatMap { store.tutorialFrames[$0] } != nil
            if !found { store.guideNext() }
        }
    }

    @ViewBuilder
    private func dim(_ hole: CGRect?) -> some View {
        let shape = Spotlight(hole: hole).fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
        if step.waitFor == nil {
            // Tap anywhere for the next tip.
            shape
                .contentShape(Rectangle())
                .onTapGesture { store.guideNext() }
        } else {
            shape.allowsHitTesting(false)
        }
    }

    /// Card sits on whichever side of the highlight has more room, or in the middle.
    @ViewBuilder
    private func card(in size: CGSize, hole: CGRect?) -> some View {
        if let hole {
            let spaceAbove = hole.minY
            let spaceBelow = size.height - hole.maxY
            VStack(spacing: 0) {
                if spaceAbove > spaceBelow {
                    Spacer(minLength: 54)
                    tipCard
                    Spacer().frame(height: max(size.height - spaceAbove + 12, 0))
                } else {
                    Spacer().frame(height: max(size.height - spaceBelow + 12, 0))
                    tipCard
                    Spacer(minLength: 30)
                }
            }
            .frame(width: size.width, height: size.height)
        } else {
            tipCard.frame(width: size.width, height: size.height)
        }
    }

    private var tipCard: some View {
        let position = (sectionSteps.firstIndex(of: index) ?? 0) + 1
        let isLast = index == Guide.steps.count - 1
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(step.section.uppercased())
                    .font(AppFont.rounded(10, .black))
                    .tracking(1.2)
                    .foregroundStyle(Palette.eyebrow)
                Spacer()
                if sectionSteps.count > 1 {
                    Text("\(position)/\(sectionSteps.count)")
                        .font(AppFont.rounded(11, .black))
                        .foregroundStyle(Palette.muted)
                }
            }
            Text(step.title).font(AppFont.rounded(18, .black))
            Text(store.guideNote ?? step.text)
                .font(AppFont.rounded(14, .semibold))
                .foregroundStyle(store.guideNote == nil ? Color(hex: 0x4F6560) : Palette.danger)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if !isLast {
                    Button("Skip tour") { store.endGuide() }
                        .font(AppFont.rounded(13, .black))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                if store.guideBackIndex != nil {
                    Button {
                        store.guideBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .black))
                            .frame(width: 36, height: 34)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink, lineWidth: 2))
                    }
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel("Previous tip")
                }
                if step.waitFor == nil {
                    Button(isLast ? "Done" : "Next") { store.guideNext() }
                        .font(AppFont.rounded(14, .black))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.yellow))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink, lineWidth: 2))
                } else {
                    Label("Your turn", systemImage: "hand.tap.fill")
                        .font(AppFont.rounded(12, .black))
                        .foregroundStyle(Palette.sharedText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Palette.mint))
                }
            }
            .padding(.top, 4)
        }
        .foregroundStyle(Palette.ink)
        .padding(14)
        .cartoonCard(radius: 18)
        .padding(.horizontal, 26)
    }
}

/// Full-screen rectangle with a rounded hole (even-odd fill), or just the hole's outline.
private struct Spotlight: Shape {
    var hole: CGRect?
    var outlineOnly = false

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
