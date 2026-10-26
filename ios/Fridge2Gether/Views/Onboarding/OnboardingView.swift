import SwiftUI

/// Welcome flow: name → who shares this fridge → create (show invite code) or join with a code.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    private enum Step { case name, household, roommates, invite, join }

    @State private var step: Step = .name
    @State private var name = ""
    @State private var code = ""
    @State private var inviteCode = ""
    @State private var busy = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private var stepLabel: String {
        switch step {
        case .name: return "WELCOME · 1 OF 3"
        case .household: return "WELCOME · 2 OF 3"
        case .roommates, .invite, .join: return "WELCOME · 3 OF 3"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(hex: 0xDFF1E9), Color(hex: 0xF9F4E8)], startPoint: .topLeading, endPoint: .bottom)
                .ignoresSafeArea()
            Circle()
                .stroke(Color(hex: 0x6DA78F, opacity: 0.4), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .frame(width: 190, height: 190)
                .offset(x: 94, y: -83)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FridgeDoodle()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                        .padding(.bottom, 30)
                    Text(stepLabel).eyebrowStyle()
                    content
                        .padding(.top, 5)
                    if let errorText {
                        Text(errorText)
                            .font(AppFont.rounded(13, .bold))
                            .foregroundStyle(Palette.danger)
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(Palette.ink)
        .disabled(busy)
        .overlay { if busy { ProgressView().tint(Palette.ink).scaleEffect(1.3) } }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .name: nameStep
        case .household: householdStep
        case .roommates: roommatesStep
        case .invite: inviteStep
        case .join: joinStep
        }
    }

    // MARK: Steps

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Let’s stock your fridge")
            subtitle("Your name helps everyone know what belongs to whom.")
            FieldLabel(text: "Your name").padding(.bottom, 6)
            TextField("e.g. Jamie", text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit(next)
                .bigField()
            Button("Continue", action: next)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmedName.isEmpty)
                .padding(.top, 18)
        }
        .onAppear { focused = true }
    }

    private var householdStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Who shares this fridge?")
            subtitle("We’ll use this to make sharing food feel effortless.")
            OptionCard(icon: "lock", title: "I live alone", detail: "Keep everything personal") {
                run { try await store.createFridge(name: trimmedName) }
            }
            OptionCard(icon: "person.2", title: "With roommates", detail: "Choose who can share") {
                step = .roommates
            }
            backButton { step = .name }
        }
    }

    private var roommatesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Meet the fridge crew")
            subtitle("One person starts the fridge. Everyone else joins with the invite code.")
            OptionCard(icon: "plus", title: "Start a new fridge", detail: "Get a code to send your roommates") {
                run {
                    inviteCode = try await store.createFridge(name: trimmedName, enter: false)
                    step = .invite
                }
            }
            OptionCard(icon: "key", title: "Join a roommate’s fridge", detail: "Enter the 6-letter code") {
                step = .join
            }
            backButton { step = .household }
        }
    }

    private var inviteStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Your fridge is ready")
            subtitle("Send this code to your roommates. They pick “Join a roommate’s fridge” and type it in.")
            InviteCodeCard(code: inviteCode)
            Button("Open my fridge") { store.enterFridge() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 20)
        }
    }

    private var joinStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Join your roommates")
            subtitle("Ask whoever started the fridge for the invite code. You can find it by tapping their profile circle.")
            FieldLabel(text: "Invite code").padding(.bottom, 6)
            TextField("e.g. K7QM2P", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .bigField()
            Button("Join fridge") {
                run { try await store.joinFridge(name: trimmedName, code: code) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(code.trimmingCharacters(in: .whitespaces).count < 6)
            .padding(.top, 18)
            backButton { step = .roommates }
        }
    }

    // MARK: Helpers

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func next() {
        guard !trimmedName.isEmpty else { return }
        errorText = nil
        step = .household
    }

    private func run(_ work: @escaping () async throws -> Void) {
        errorText = nil
        busy = true
        Task {
            do { try await work() } catch { errorText = AppStore.friendly(error) }
            busy = false
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(AppFont.rounded(31, .black))
            .tracking(-1)
            .padding(.bottom, 8)
    }

    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(AppFont.rounded(14, .semibold))
            .foregroundStyle(Color(hex: 0x5F7570))
            .lineSpacing(3)
            .padding(.bottom, 22)
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button("Back", action: action)
            .font(AppFont.rounded(13, .black))
            .foregroundStyle(Color(hex: 0x367D64))
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
    }
}

private extension View {
    func bigField() -> some View {
        self
            .font(AppFont.rounded(17, .heavy))
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 15).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.ink, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 15).fill(Palette.ink).offset(x: 2, y: 3))
    }
}

struct OptionCard: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.mint))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(AppFont.rounded(16, .black))
                    Text(detail).font(AppFont.rounded(12, .semibold)).foregroundStyle(Palette.muted)
                }
                Spacer()
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .frame(minHeight: 88)
            .cartoonCard()
        }
        .buttonStyle(.plain)
    }
}

struct InviteCodeCard: View {
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            Text(code)
                .font(.system(size: 38, weight: .black, design: .monospaced))
                .tracking(6)
                .textSelection(.enabled)
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
                ShareLink(item: "Join our fridge on Fridge2Gether with code \(code)") {
                    Label("Send", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle(fill: Palette.mint))
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(18)
        .frame(maxWidth: .infinity)
        .cartoonCard(fill: Palette.expiringYellow)
    }
}
