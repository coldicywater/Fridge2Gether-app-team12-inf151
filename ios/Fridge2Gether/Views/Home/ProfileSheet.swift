import SwiftUI

/// Tap the avatar: edit your name, see the fridge crew, share the invite code.
struct ProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmLeave = false

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
        .confirmationDialog("Leave this fridge?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                dismiss()
                Task { await store.leaveFridge() }
            }
        } message: {
            Text("Your food stays with your roommates. You can join again with the invite code.")
        }
    }

    private func save() {
        guard name.trimmingCharacters(in: .whitespaces) != store.userName else { return }
        Task { await store.updateName(name) }
    }
}
