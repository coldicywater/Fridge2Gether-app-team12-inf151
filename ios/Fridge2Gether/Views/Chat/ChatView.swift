import SwiftUI

/// Group chat for the fridge on screen. Everyone who shares the fridge is in it.
/// Besides normal messages it shows automatic notes (food shared, used up, claimed),
/// food requests roommates can answer, and offers that can be claimed right here.
struct ChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var asking = false
    @State private var askDraft = ""
    @State private var offering = false
    @FocusState private var typing: Bool

    private var subtitle: String {
        let names = store.roommates.map(\.name)
        guard !names.isEmpty else { return "Just you so far" }
        return "You, " + names.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Palette.ink).frame(height: 2)
            if store.roommates.isEmpty && store.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .background(ScreenBackground())
        .foregroundStyle(Palette.ink)
        .onAppear { store.markChatRead() }
        .onChange(of: store.messages.count) { store.markChatRead() }
        .alert("Ask for food", isPresented: $asking) {
            TextField("e.g. Can I have 2 eggs?", text: $askDraft)
            Button("Send") {
                store.askFor(askDraft)
                askDraft = ""
            }
            Button("Cancel", role: .cancel) { askDraft = "" }
        } message: {
            Text("Your roommates can answer with “I've got it”.")
        }
        .sheet(isPresented: $offering) {
            OfferFoodSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .storeErrorAlert()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "refrigerator")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color(hex: 0x2E765E))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 15).fill(Palette.fridgeBlue))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 1) {
                Text("Fridge chat").font(AppFont.rounded(20, .black))
                Text(subtitle)
                    .font(AppFont.rounded(12, .semibold))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Palette.card))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
            }
            .accessibilityLabel("Close chat")
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            FridgeDoodle(label: "say hi", size: 90)
            Text("No roommates yet")
                .font(AppFont.rounded(18, .black))
            Text("Share your invite code from your profile. Everyone in this fridge chats here.")
                .font(AppFont.rounded(13, .semibold))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if store.messages.isEmpty {
                        Text("Say hi to your roommates!")
                            .font(AppFont.hand(18))
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 40)
                    }
                    ForEach(Array(store.messages.enumerated()), id: \.element.id) { index, message in
                        if showsTime(at: index) {
                            Text(Self.timeLabel(message.createdAt))
                                .font(AppFont.rounded(10, .heavy))
                                .foregroundStyle(Palette.muted)
                                .padding(.top, 8)
                        }
                        row(message, index: index)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: store.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: typing) {
                guard typing else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ message: ChatMessage, index: Int) -> some View {
        switch message.kind {
        case .event:
            EventNote(text: message.text)
        case .text:
            TextBubble(message: message, mine: message.senderId == store.uid, showName: showsName(at: index))
        case .request:
            RequestCard(message: message)
        case .offer:
            OfferCard(message: message)
        }
    }

    /// Time label when there's a gap of 15+ minutes.
    private func showsTime(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let gap = store.messages[index].createdAt.timeIntervalSince(store.messages[index - 1].createdAt)
        return gap > 15 * 60
    }

    /// Name above a roommate's bubble, skipped when they send several in a row.
    private func showsName(at index: Int) -> Bool {
        guard index > 0, !showsTime(at: index) else { return true }
        let previous = store.messages[index - 1]
        return previous.kind != .text || previous.senderId != store.messages[index].senderId
    }

    static func timeLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button { asking = true } label: {
                    Label("Ask for food", systemImage: "hand.raised")
                }
                Button { offering = true } label: {
                    Label("Offer my food", systemImage: "gift")
                }
                .disabled(store.roommates.isEmpty)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Palette.mint))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
            }
            .accessibilityLabel("Ask for or offer food")

            TextField("Message your fridge", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .font(AppFont.rounded(15, .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 21).fill(Color(hex: 0xFFFDF9)))
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(Palette.ink, lineWidth: 2))

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Palette.yellow))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Palette.cream.overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 2) })
    }

    private func send() {
        store.sendChat(draft)
        draft = ""
    }
}

// MARK: - Rows

/// "Alex used up the milk."
private struct EventNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.rounded(12, .bold))
            .foregroundStyle(Color(hex: 0x587069))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: 0xE7EEE9)))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }
}

private struct TextBubble: View {
    let message: ChatMessage
    let mine: Bool
    let showName: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if mine { Spacer(minLength: 50) }
            if !mine {
                Avatar(name: message.senderName)
                    .opacity(showName ? 1 : 0)
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if showName && !mine {
                    Text(message.senderName)
                        .font(AppFont.rounded(11, .heavy))
                        .foregroundStyle(Palette.muted)
                        .padding(.leading, 4)
                }
                Text(message.text)
                    .font(AppFont.rounded(15, .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 17).fill(mine ? Color(hex: 0xFCE3A3) : Palette.card))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.ink, lineWidth: 2))
                    .textSelection(.enabled)
            }
            if !mine { Spacer(minLength: 50) }
        }
    }
}

private struct Avatar: View {
    let name: String
    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(AppFont.rounded(12, .black))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Palette.roommate))
            .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
    }
}

/// "Can I have 2 eggs?" with an "I've got it" button for everyone else.
private struct RequestCard: View {
    @Environment(AppStore.self) private var store
    let message: ChatMessage

    private var mine: Bool { message.senderId == store.uid }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill").foregroundStyle(Palette.expiringText)
                Text(mine ? "You asked" : "\(message.senderName) is asking")
                    .font(AppFont.rounded(11, .black))
                    .foregroundStyle(Palette.expiringText)
            }
            Text(message.text).font(AppFont.rounded(15, .heavy))
            if let helper = message.fulfilledByName {
                Label(message.fulfilledById == store.uid ? "You've got it" : "\(helper) has it", systemImage: "checkmark.circle.fill")
                    .font(AppFont.rounded(12, .black))
                    .foregroundStyle(Palette.sharedText)
            } else if mine {
                Text("Waiting for a roommate…")
                    .font(AppFont.rounded(12, .semibold))
                    .foregroundStyle(Palette.muted)
            } else {
                Button("I've got it") { Task { await store.fulfill(message) } }
                    .font(AppFont.rounded(12, .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x72B88A)))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.ink, lineWidth: 2))
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .cartoonCard(fill: Color(hex: 0xFFF2C9), radius: 17, shadow: 2)
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }
}

/// "Carrie is sharing milk" with the food sticker and "I'll Take It" for the people it was offered to.
private struct OfferCard: View {
    @Environment(AppStore.self) private var store
    let message: ChatMessage

    private var offer: Offer? { store.offers.first { $0.id == message.offerId } }
    private var mine: Bool { message.senderId == store.uid }

    var body: some View {
        let food = offer.flatMap { store.food(id: $0.foodId) }
        HStack(spacing: 10) {
            if let food {
                StickerView(food: food, size: .small, showLabel: false)
            } else {
                Image(systemName: "gift.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.green)
                    .frame(width: 50, height: 50)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text).font(AppFont.rounded(13, .heavy))
                status(offer: offer, foodExists: food != nil)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: 300, alignment: .leading)
        .cartoonCard(fill: Color(hex: 0xD9EFD5), radius: 17, shadow: 2)
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    @ViewBuilder
    private func status(offer: Offer?, foodExists: Bool) -> some View {
        if let offer, let taker = offer.claimedByName {
            Label(offer.claimedById == store.uid ? "You took it" : "\(taker) took it", systemImage: "checkmark.circle.fill")
                .font(AppFont.rounded(12, .black))
                .foregroundStyle(Palette.sharedText)
        } else if let offer, foodExists, offer.recipientIds.contains(store.uid) {
            Button("I'll Take It") { Task { await store.claim(offer) } }
                .font(AppFont.rounded(12, .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x72B88A)))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.ink, lineWidth: 2))
        } else if offer == nil || !foodExists {
            Text("No longer available")
                .font(AppFont.rounded(12, .semibold))
                .foregroundStyle(Palette.muted)
        } else if mine {
            Text("Waiting for a roommate…")
                .font(AppFont.rounded(12, .semibold))
                .foregroundStyle(Palette.muted)
        }
    }
}

// MARK: - Offer my food

/// Pick one of my foods and offer it to everyone in the fridge.
private struct OfferFoodSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var myFoods: [Food] { store.visibleFoods.filter { $0.ownerId == store.uid } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Offer my food").font(AppFont.rounded(22, .black))
                Text("Pick something to share with everyone. They can take it from the chat.")
                    .font(AppFont.rounded(12, .semibold))
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 6)
                if myFoods.isEmpty {
                    Text("You don't have any food in this fridge yet.")
                        .font(AppFont.hand(17))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }
                ForEach(myFoods) { food in
                    Button {
                        Task { await store.offer(food, to: [], everyone: true) }
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            StickerView(food: food, size: .small, showLabel: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name).font(AppFont.rounded(15, .black))
                                Text("\(food.quantityLabel) · \(food.daysLabel)")
                                    .font(AppFont.rounded(11, .semibold))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "gift").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .cartoonCard(radius: 16, shadow: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .padding(.top, 10)
            .foregroundStyle(Palette.ink)
        }
        .background(ScreenBackground())
    }
}
