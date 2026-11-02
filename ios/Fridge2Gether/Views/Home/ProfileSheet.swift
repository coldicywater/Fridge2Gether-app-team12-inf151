import SwiftUI

/// Tap the avatar: edit your name, see the fridge crew, share the invite code.
struct ProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmLeave = false
    @State private var joinCode = ""
    @State private var busy = false
    @State private var fridgeError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("EDIT YOUR FRIDGE CREW").eyebrowStyle()
                    Spacer()
                    Button {
                        save()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Palette.card))
                            .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
                    }
                    .accessibilityLabel("Close")
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Your name")
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .fieldStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Fridge crew")
                    if store.roommates.isEmpty {
                        Text("Just you for now. Send the code below to add roommates.")
                            .font(AppFont.rounded(13, .semibold))
                            .foregroundStyle(Palette.muted)
                    }
                    ForEach(store.roommates) { roommate in
                        HStack(spacing: 10) {
                            Text(String(roommate.name.prefix(1)).uppercased())
                                .font(AppFont.rounded(12, .black))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Palette.roommate))
                                .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                            Text(roommate.name).font(AppFont.rounded(15, .heavy))
                        }
                    }
                }

                if let code = store.fridge?.inviteCode {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Invite code")
                        InviteCodeCard(code: code)
                    }
                }

                fridgesSection

                Button("Leave this fridge") { confirmLeave = true }
                    .font(AppFont.rounded(13, .black))
                    .foregroundStyle(Palette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(22)
            .foregroundStyle(Palette.ink)
        }
        .background(LinearGradient(colors: [Color(hex: 0xDFF1E9), Palette.cream], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onAppear { name = store.userName }
        .task { await store.loadMyFridges() }
        .disabled(busy)
        .confirmationDialog("Leave this fridge?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                dismiss()
                Task { await store.leaveFridge() }
            }
        } message: {
            Text(store.fridgeIds.count > 1
                 ? "Your food in this fridge stays with your roommates. You'll switch to your other fridge."
                 : "This is your only fridge. You'll need to start or join a fridge again afterwards.")
        }
    }

    // MARK: Fridges

    /// Every fridge I belong to: switch between them, join another, or start a new one.
    /// Joining no longer replaces the fridge you already have.
    private var fridgesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Your fridges")
            ForEach(store.myFridges, id: \.id) { item in
                let isCurrent = item.id == store.currentFridgeId
                Button {
                    guard !isCurrent else { return }
                    Task { await store.switchFridge(to: item.id) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "refrigerator")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Palette.fridgeBlue))
                        Text(item.displayName(for: store.uid))
                            .font(AppFont.rounded(14, .heavy))
                            .lineLimit(1)
                        Spacer()
                        if isCurrent {
                            Text("Open").font(AppFont.rounded(11, .black)).foregroundStyle(Palette.activeGreen)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(isCurrent ? Palette.mint : .white))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? Color(hex: 0x3D896D) : Palette.lightBorder, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("Invite code", text: $joinCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .fieldStyle()
                Button("Join") { join() }
                    .buttonStyle(SecondaryButtonStyle(fill: Palette.mint))
                    .frame(width: 90)
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 6)
            }
            .padding(.top, 4)

            Button {
                run { try await store.createFridge(name: store.userName) }
            } label: {
                Label("Start a new fridge", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle())

            if let fridgeError {
                Text(fridgeError)
                    .font(AppFont.rounded(12, .bold))
                    .foregroundStyle(Palette.danger)
            }
        }
    }

    private func join() {
        let code = joinCode
        run {
            try await store.joinFridge(name: store.userName, code: code)
            joinCode = ""
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        fridgeError = nil
        busy = true
        Task {
            do { try await work() } catch { fridgeError = AppStore.friendly(error) }
            await store.loadMyFridges()
            busy = false
        }
    }

    private func save() {
        guard name.trimmingCharacters(in: .whitespaces) != store.userName else { return }
        Task { await store.updateName(name) }
    }
}
