import SwiftUI

/// Bottom sheet for one ingredient. Ports DetailSheet from App.tsx:
/// main → "I Used Some" (portion cups) / "Used Up" / "Change sharing" or "Share it with..." for almost-expired food.
struct FoodDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let foodId: String
    let onWhatCanIMake: () -> Void

    private enum Panel { case main, quantity, share, rescue, usedUp }

    @State private var panel: Panel = .main
    @State private var portion: Double = 1
    @State private var sharing: Sharing = .justMe
    @State private var selected: Set<String> = []
    @State private var loaded = false

    var body: some View {
        Group {
            if let food = store.food(id: foodId) {
                content(food)
            } else {
                // Removed (used up, or by a roommate) while the sheet was open.
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(Palette.card.ignoresSafeArea())
    }

    private func content(_ food: Food) -> some View {
        let isMine = food.ownerId == store.uid
        let almostExpired = food.freshness != .fresh

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                HStack(spacing: 16) {
                    StickerView(food: food, size: .large, showLabel: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.daysLabel)
                            .font(AppFont.rounded(10, .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(pillColor(food.freshness)))
                        Text(food.name).font(AppFont.rounded(25, .black))
                        Text("Best before \(food.dateLabel)")
                            .font(AppFont.rounded(13, .semibold))
                            .foregroundStyle(Color(hex: 0x6C7D78))
                    }
                }
                .padding(.top, 24)

                // Facts grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible())], spacing: 7) {
                    fact("Quantity", food.quantityLabel)
                    fact("Expires", "\(food.dateLabel) · \(food.daysLabel)")
                    fact("Owner", isMine ? "\(store.userName) (you)" : food.ownerName)
                    fact("Sharing", sharingLabel(food, isMine: isMine))
                }
                .padding(.top, 16)
                .padding(.bottom, 14)

                switch panel {
                case .main: mainActions(food, isMine: isMine, almostExpired: almostExpired)
                case .quantity: quantityPanel(food)
                case .usedUp: usedUpPanel(food)
                case .share: sharePanel(food)
                case .rescue: rescuePanel(food)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .foregroundStyle(Palette.ink)
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            portion = PortionSelector.snap(food.amount / max(food.fullAmount, 0.01))
            sharing = food.sharing
            selected = Set(food.sharedWith)
        }
        .animation(.easeOut(duration: 0.2), value: panel)
    }

    // MARK: Panels

    @ViewBuilder
    private func mainActions(_ food: Food, isMine: Bool, almostExpired: Bool) -> some View {
        VStack(spacing: 8) {
            if almostExpired {
                Button {
                    onWhatCanIMake()
                } label: {
                    Label("What can I make with it?", systemImage: "sparkles")
                }
                .buttonStyle(SecondaryButtonStyle(fill: Color(hex: 0xFFF0C3)))
            }
            HStack(spacing: 8) {
                Button("I Used Some") { panel = .quantity }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Used Up") {
                    if almostExpired {
                        panel = .usedUp
                    } else {
                        Task { await store.remove(food) }
                        dismiss()
                    }
                }
                .buttonStyle(SecondaryButtonStyle(textColor: Palette.danger))
                if almostExpired && isMine && !store.roommates.isEmpty {
                    shareButton(title: "Share it with...") {
                        sharing = .selected
                        panel = .rescue
                    }
                }
            }
            if !almostExpired && isMine {
                shareButton(title: "Change sharing") { panel = .share }
            }
        }
    }

    private func shareButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "person.2")
        }
        .buttonStyle(SecondaryButtonStyle(fill: Palette.mint))
    }

    private func quantityPanel(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            panelHeading("How much is left?", detail: "Select the remaining level")
            PortionSelector(value: $portion)
            Button("Save remaining amount") {
                let amount = (food.fullAmount * portion * 100).rounded() / 100
                Task { await store.setAmount(food, amount: amount) }
                if amount <= 0 { dismiss() } else { panel = .main }
            }
            .buttonStyle(PrimaryButtonStyle())
            cancelButton
        }
    }

    private func usedUpPanel(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            panelHeading("Remove \(food.name)?", detail: nil)
            Text("This marks the ingredient as used up and removes it from your fridge.")
                .font(AppFont.rounded(13, .semibold))
                .foregroundStyle(Color(hex: 0x687A75))
            HStack(spacing: 8) {
                Button("Cancel") { panel = .main }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Yes, Used Up") {
                    Task { await store.remove(food) }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func sharePanel(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Who can see this?").font(AppFont.rounded(15, .black))
                Spacer()
                Button("Done") {
                    let ids = Array(selected)
                    let finalSharing: Sharing = (sharing == .selected && ids.isEmpty) ? .justMe : sharing
                    Task { await store.setSharing(food, sharing: finalSharing, with: ids) }
                    panel = .main
                }
                .font(AppFont.rounded(14, .black))
                .foregroundStyle(Color(hex: 0x3D896D))
            }
            HStack(spacing: 5) {
                ForEach(store.roommates.isEmpty ? [Sharing.justMe] : Sharing.allCases, id: \.self) { option in
                    Button(option.label) { sharing = option }
                        .buttonStyle(ChipButtonStyle(selected: sharing == option))
                }
            }
            if store.roommates.isEmpty {
                Text("Invite roommates from your profile to share food.")
                    .font(AppFont.rounded(12, .semibold))
                    .foregroundStyle(Palette.muted)
            }
            if sharing == .selected {
                RoommatePicker(roommates: store.roommates, selected: $selected)
            }
        }
    }

    private func rescuePanel(_ food: Food) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            panelHeading("Share it with...", detail: "Select one or more")
            checkboxRow("Everyone", checked: sharing == .everyone) {
                sharing = .everyone
                selected = []
            }
            ForEach(store.roommates) { roommate in
                checkboxRow(roommate.name, checked: sharing == .selected && selected.contains(roommate.id)) {
                    sharing = .selected
                    if selected.contains(roommate.id) { selected.remove(roommate.id) } else { selected.insert(roommate.id) }
                }
            }
            Button("Share ingredient") {
                let everyone = sharing == .everyone
                Task { await store.offer(food, to: Array(selected), everyone: everyone) }
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(sharing == .selected && selected.isEmpty)
            .padding(.top, 4)
            Text("They’ll get a notification and it shows up in their Almost Expired shelf.")
                .font(AppFont.rounded(11, .semibold))
                .foregroundStyle(Palette.muted)
            cancelButton
        }
    }

    // MARK: Small pieces

    private var cancelButton: some View {
        Button("Cancel") { panel = .main }
            .font(AppFont.rounded(13, .black))
            .foregroundStyle(Color(hex: 0x367D64))
            .frame(maxWidth: .infinity)
    }

    private func panelHeading(_ title: String, detail: String?) -> some View {
        HStack {
            Text(title).font(AppFont.rounded(15, .black))
            Spacer()
            if let detail {
                Text(detail).font(AppFont.rounded(11, .heavy)).foregroundStyle(Palette.muted)
            }
        }
    }

    private func checkboxRow(_ title: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(checked ? .white : .clear)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(checked ? Palette.green : Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(checked ? Palette.ink : Color(hex: 0x7F918B), lineWidth: 1.5))
                Text(title).font(AppFont.rounded(14, .black))
                Spacer()
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 11).fill(checked ? Color(hex: 0xE4F2EB) : .white))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(checked ? Color(hex: 0x3D896D) : Palette.lightBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(AppFont.rounded(9, .black))
                .tracking(0.8)
                .foregroundStyle(Color(hex: 0x76857F))
            Text(value).font(AppFont.rounded(14, .heavy)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(hex: 0xD4D9D4), lineWidth: 1.5))
    }

    private func sharingLabel(_ food: Food, isMine: Bool) -> String {
        if !isMine { return food.isShared ? "Shared with you" : "Private" }
        switch food.sharing {
        case .justMe: return "Just Me"
        case .everyone: return "Everyone"
        case .selected:
            let names = food.sharedWith.map(store.memberName)
            return names.isEmpty ? "Just Me" : names.joined(separator: ", ")
        }
    }

    private func pillColor(_ freshness: Freshness) -> Color {
        switch freshness {
        case .fresh: return Color(hex: 0x4C9E74)
        case .soon: return Color(hex: 0xD89E13)
        case .urgent: return Palette.coral
        }
    }
}

// MARK: - Roommate picker

struct RoommatePicker: View {
    let roommates: [Member]
    @Binding var selected: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(roommates) { roommate in
                    let isOn = selected.contains(roommate.id)
                    Button {
                        if isOn { selected.remove(roommate.id) } else { selected.insert(roommate.id) }
                    } label: {
                        VStack(spacing: 3) {
                            Text(String(roommate.name.prefix(1)).uppercased())
                                .font(AppFont.rounded(11, .black))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Palette.roommate))
                            Text(roommate.name).font(AppFont.rounded(11, .black)).lineLimit(1)
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(minWidth: 70)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 11).fill(isOn ? Palette.mint : .white))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(isOn ? Color(hex: 0x3D896D) : Palette.lightBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Portion cups

/// Five cups: Empty, ¼, ½, ¾, Full.
struct PortionSelector: View {
    @Binding var value: Double
    var compact = false

    static let options: [(label: String, value: Double)] = [
        ("Empty", 0), ("¼ Full", 0.25), ("½ Full", 0.5), ("¾ Full", 0.75), ("Full", 1),
    ]

    static func snap(_ raw: Double) -> Double {
        options.map { $0.value }.min { abs($0 - raw) < abs($1 - raw) } ?? 1
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 5) {
            ForEach(Self.options.indices, id: \.self) { index in
                let option = Self.options[index]
                let isOn = value == option.value
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { value = option.value }
                } label: {
                    VStack(spacing: compact ? 3 : 5) {
                        cup(fill: option.value)
                        Text(option.label)
                            .font(AppFont.rounded(compact ? 8 : 9, .black))
                            .foregroundStyle(Color(hex: 0x62736F))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 5 : 7)
                    .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? Color(hex: 0xFFF3C8) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isOn ? Palette.ink : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cup(fill: Double) -> some View {
        let width: CGFloat = compact ? 25 : 36
        let height: CGFloat = compact ? 32 : 45
        let shape = UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: compact ? 8 : 11,
                                           bottomTrailingRadius: compact ? 8 : 11, topTrailingRadius: 4)
        return ZStack(alignment: .bottom) {
            shape.fill(Palette.card)
            Rectangle()
                .fill(Color(hex: 0xEFB944))
                .frame(height: height * fill)
                .overlay(alignment: .top) {
                    if fill > 0 { Rectangle().fill(Color(hex: 0x9E7221)).frame(height: 1.5) }
                }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.stroke(Palette.ink, lineWidth: 2))
        .rotationEffect(.degrees(-1))
    }
}
