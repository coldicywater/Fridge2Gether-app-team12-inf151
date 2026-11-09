import SwiftUI

/// "5 ITEMS FOUND · Review & Edit". Tap a sticker to edit it, then add everything at once.
struct ReviewEditView: View {
    @Environment(AppStore.self) private var store
    @Binding var items: [DetectedItem]
    let note: String?
    let onBack: () -> Void
    let onSaved: () -> Void

    @State private var activeIndex = 0
    @State private var saving = false
    @State private var errorText: String?

    private var safeIndex: Int { min(activeIndex, max(items.count - 1, 0)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundBackButton(action: onBack)
                    .padding(.bottom, 14)
                Text("\(items.count) \(items.count == 1 ? "ITEM" : "ITEMS") FOUND").eyebrowStyle()
                Text("Review & Edit")
                    .font(AppFont.rounded(30, .black))
                    .tracking(-1.2)
                    .padding(.bottom, 10)

                stickerStrip

                if !items.isEmpty {
                    let id = items[safeIndex].id
                    form(item: binding(for: id), id: id)
                        .id(id)
                }

                if let errorText {
                    Text(errorText)
                        .font(AppFont.rounded(13, .bold))
                        .foregroundStyle(Palette.danger)
                        .padding(.top, 10)
                }

                Button {
                    save()
                } label: {
                    HStack(spacing: 7) {
                        Text("Add \(validCount) · AI organize")
                        Image(systemName: "sparkles")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(validCount == 0 || saving)
                .padding(.top, 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .foregroundStyle(Palette.ink)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            LinearGradient(colors: [Color(hex: 0xEEF8F6), Color(hex: 0xF9F4E8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .overlay { if saving { ProgressView().tint(Palette.ink).scaleEffect(1.3) } }
    }

    private var validCount: Int {
        items.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    // MARK: Stickers

    private var stickerStrip: some View {
        VStack(spacing: 9) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let active = index == safeIndex
                        Button {
                            withAnimation(.spring(duration: 0.25)) { activeIndex = index }
                        } label: {
                            StickerView(name: item.name.isEmpty ? "?" : item.name, image: item.sticker, size: .small, showLabel: false)
                                .overlay(alignment: .topTrailing) {
                                    Text("\(index + 1)")
                                        .font(AppFont.rounded(10, .black))
                                        .foregroundStyle(Palette.ink)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Palette.yellow))
                                        .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
                                        .offset(x: 2, y: -2)
                                }
                                .scaleEffect(active ? 1.08 : 0.82)
                                .opacity(active ? 1 : 0.55)
                                .offset(y: active ? -3 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
                .frame(minWidth: 340)
            }
            Label(note ?? "AI found \(items.count) \(items.count == 1 ? "grocery" : "groceries")", systemImage: "sparkles")
                .font(AppFont.rounded(11, .black))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 12).fill(note == nil ? Color(hex: 0xD6EEE3) : Color(hex: 0xFFF0C3)))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 14)
    }

    // MARK: Form

    /// Looks items up by id so a removed item can never index out of range.
    private func binding(for id: UUID) -> Binding<DetectedItem> {
        Binding(
            get: { items.first { $0.id == id } ?? DetectedItem(name: "", expiry: Date(), amount: 1, unit: "pieces") },
            set: { newValue in
                if let i = items.firstIndex(where: { $0.id == id }) { items[i] = newValue }
            }
        )
    }

    private func form(item: Binding<DetectedItem>, id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                FieldLabel(text: "Food name")
                TextField("e.g. Avocado", text: item.name)
                    .textInputAutocapitalization(.words)
                    .fieldStyle()
            }
            VStack(alignment: .leading, spacing: 5) {
                FieldLabel(text: "Estimated expiry")
                DatePicker("", selection: item.expiry, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Palette.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .frame(height: 48)
                    .background(RoundedRectangle(cornerRadius: 13).fill(Color(hex: 0xFFFDF9)))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.ink, lineWidth: 2))
            }
            QuantityEditor(amount: item.amount, unit: item.unit)

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Sharing")
                HStack(spacing: 5) {
                    ForEach(store.roommates.isEmpty ? [Sharing.justMe] : Sharing.allCases, id: \.self) { option in
                        Button(option.label) { item.wrappedValue.sharing = option }
                            .buttonStyle(ChipButtonStyle(selected: item.wrappedValue.sharing == option))
                    }
                }
                if item.wrappedValue.sharing == .selected {
                    RoommatePicker(
                        roommates: store.roommates,
                        selected: Binding(
                            get: { Set(item.wrappedValue.sharedWith) },
                            set: { item.wrappedValue.sharedWith = Array($0) }
                        )
                    )
                }
            }

            if items.count > 1 {
                Button(role: .destructive) {
                    items.removeAll { $0.id == id }
                    activeIndex = max(0, min(activeIndex, items.count - 1))
                } label: {
                    Label("Not food? Remove this item", systemImage: "trash")
                        .font(AppFont.rounded(12, .black))
                        .foregroundStyle(Palette.danger)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func save() {
        errorText = nil
        saving = true
        // Selected Roommates with nobody picked falls back to Just Me.
        let cleaned = items.map { item -> DetectedItem in
            var copy = item
            if copy.sharing == .selected && copy.sharedWith.isEmpty { copy.sharing = .justMe }
            return copy
        }
        Task {
            do {
                try await store.addFoods(cleaned)
                saving = false
                onSaved()
            } catch {
                saving = false
                errorText = AppStore.friendly(error)
            }
        }
    }
}

/// Quantity as a number with − / + and a counting word ("2 apples", "1 plate").
/// The word can be typed or picked from the menu.
struct QuantityEditor: View {
    @Binding var amount: Double
    @Binding var unit: String
    /// The word the AI picked, kept at the top of the menu after the user changes it.
    @State private var original: String?

    private var units: [String] {
        var list = DetectedItem.commonUnits
        if let original, !original.isEmpty, !list.contains(original) { list.insert(original, at: 0) }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                FieldLabel(text: "Quantity")
                Spacer()
                Text(Food.quantityLabel(amount, unit))
                    .font(AppFont.rounded(11, .black))
                    .foregroundStyle(Palette.sharedText)
            }
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    stepButton("minus") { amount = max(amount - 1, 0) }
                        .disabled(amount < 1)
                    TextField("1", value: $amount, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(AppFont.rounded(16, .black))
                        .frame(width: 46)
                    stepButton("plus") { amount = (amount + 1).rounded(.down) }
                }
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color(hex: 0xFFFDF9)))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.ink, lineWidth: 2))

                HStack(spacing: 4) {
                    TextField("apples", text: $unit)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(AppFont.rounded(15, .heavy))
                    Menu {
                        ForEach(units, id: \.self) { option in
                            Button(option) { unit = option }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 30, height: 40)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Pick a unit")
                }
                .padding(.leading, 13)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color(hex: 0xFFFDF9)))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.ink, lineWidth: 2))
            }
        }
        .foregroundStyle(Palette.ink)
        .onAppear { if original == nil { original = unit } }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .frame(width: 40, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "plus" ? "One more" : "One less")
    }
}
