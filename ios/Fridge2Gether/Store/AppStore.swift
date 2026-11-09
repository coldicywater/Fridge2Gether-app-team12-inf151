import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Single source of truth for the app. Mirrors the state that App.tsx kept in useState,
/// but backed by Firestore so every roommate sees the same fridge in real time.
@MainActor
@Observable
final class AppStore {
    enum Phase: Equatable {
        case loading
        case missingFirebaseConfig
        case onboarding
        case ready
        case error(String)
    }

    var phase: Phase = .loading
    var uid = ""
    var userName = ""
    var fridge: Fridge?
    /// Every fridge I belong to. Joining another fridge adds to this list instead of replacing it.
    var fridgeIds: [String] = []
    /// Loaded copies of the fridges in `fridgeIds`, for the fridge switcher.
    var myFridges: [Fridge] = []
    /// The fridge on screen. Mutations use this, so they don't depend on the fridge listener having loaded.
    private(set) var currentFridgeId = ""
    var foods: [Food] = []
    var offers: [Offer] = []
    /// Chat for the fridge on screen, oldest first.
    var messages: [ChatMessage] = []
    /// When I last looked at this fridge's chat. Roommates' messages after it count as unread.
    var chatLastRead: Date = .distantPast

    var recipes: [Recipe] = []
    var recipesLoading = false
    var recipesError: String?
    /// Ingredients ticked on the Recipes page.
    var recipeSelection: Set<String> = []
    /// Ingredients the current recipes were made around. Empty means "anything in the fridge".
    var recipesFocus: [String] = []
    private var recipesInventoryKey = ""

    /// Food ids that were just shared with me; they glow on the fridge until opened.
    var highlightedFoodIds: Set<String> = []

    /// Set when a save fails, so the UI can say so instead of failing silently.
    var lastError: String?

    @ObservationIgnored private var listeners: [ListenerRegistration] = []
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Startup

    func start(firebaseConfigured: Bool) async {
        guard firebaseConfigured else {
            phase = .missingFirebaseConfig
            return
        }
        do {
            if Auth.auth().currentUser == nil {
                _ = try await Auth.auth().signInAnonymously()
            }
            guard let user = Auth.auth().currentUser else {
                phase = .error("Could not sign in.")
                return
            }
            uid = user.uid
            let snapshot = try await db.collection("users").document(uid).getDocument()
            let data = snapshot.data() ?? [:]
            var ids = data["fridgeIds"] as? [String] ?? []
            let current = data["fridgeId"] as? String ?? ""
            // Older accounts only stored one fridgeId.
            if !current.isEmpty && !ids.contains(current) { ids.insert(current, at: 0) }
            fridgeIds = ids
            if let name = data["name"] as? String { userName = name }
            let startId: String? = current.isEmpty ? ids.first : current
            if !userName.isEmpty, let fridgeId = startId {
                attach(fridgeId: fridgeId)
                phase = .ready
            } else {
                phase = .onboarding
            }
        } catch {
            phase = .error(Self.friendly(error))
        }
    }

    func retry() async {
        phase = .loading
        await start(firebaseConfigured: true)
    }

    // MARK: - Onboarding

    /// "I live alone" and "With roommates → create" both make a new fridge.
    /// Pass `enter: false` to stay on onboarding (to show the invite code first), then call `enterFridge()`.
    @discardableResult
    func createFridge(name: String, enter: Bool = true) async throws -> String {
        let ref = db.collection("fridges").document()
        let fridge = Fridge(
            inviteCode: Self.makeInviteCode(),
            memberIds: [uid],
            memberNames: [uid: name],
            createdAt: Date()
        )
        try ref.setData(from: fridge)
        userName = name
        if !fridgeIds.contains(ref.documentID) { fridgeIds.append(ref.documentID) }
        attach(fridgeId: ref.documentID)
        try await persistUser()
        if enter { enterFridge() }
        return fridge.inviteCode
    }

    func enterFridge() {
        phase = .ready
        NotificationService.requestPermission()
    }

    /// "With roommates → join": enter the code a roommate shared.
    func joinFridge(name: String, code: String) async throws {
        let cleaned = code.uppercased().trimmingCharacters(in: .whitespaces)
        let result = try await db.collection("fridges")
            .whereField("inviteCode", isEqualTo: cleaned)
            .limit(to: 1)
            .getDocuments()
        guard let doc = result.documents.first else {
            throw AppError.message("No fridge found with code \(cleaned).")
        }
        let wasMember = (doc.data()["memberIds"] as? [String] ?? []).contains(uid)
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([uid]),
            "memberNames.\(uid)": name,
        ])
        userName = name
        // Keep the fridges I already have; just add this one and switch to it.
        if !fridgeIds.contains(doc.documentID) { fridgeIds.append(doc.documentID) }
        attach(fridgeId: doc.documentID)
        if !wasMember { post(message(.event, "\(name) joined the fridge."), to: doc.documentID) }
        try await persistUser()
        phase = .ready
        NotificationService.requestPermission()
    }

    /// Show another fridge I belong to.
    func switchFridge(to fridgeId: String) async {
        guard fridgeIds.contains(fridgeId), fridgeId != currentFridgeId else { return }
        attach(fridgeId: fridgeId)
        do { try await persistUser() } catch { report(error) }
    }

    /// Fetches every fridge in `fridgeIds` for the switcher. Drops ones I'm no longer a member of.
    func loadMyFridges() async {
        var loaded: [Fridge] = []
        for id in fridgeIds {
            guard
                let snapshot = try? await db.collection("fridges").document(id).getDocument(),
                snapshot.exists,
                var item = try? snapshot.data(as: Fridge.self),
                item.memberIds.contains(uid)
            else { continue }
            item.id = id
            loaded.append(item)
        }
        myFridges = loaded
    }

    private func persistUser() async throws {
        try await db.collection("users").document(uid).setData([
            "name": userName,
            "fridgeId": currentFridgeId,
            "fridgeIds": fridgeIds,
        ], merge: true)
    }

    func updateName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let fridge else { return }
        userName = trimmed
        try? await db.collection("users").document(uid).updateData(["name": trimmed])
        try? await db.collection("fridges").document(fridge.id).updateData(["memberNames.\(uid)": trimmed])
        // Keep the owner label on my food in sync.
        let batch = db.batch()
        for food in foods where food.ownerId == uid {
            batch.updateData(["ownerName": trimmed], forDocument: foodsRef(fridge.id).document(food.id))
        }
        try? await batch.commit()
    }

    /// Leaves only the fridge on screen. If I have other fridges I land in the next one;
    /// my profile is kept either way (it used to be deleted, which sent people back to sign-up).
    func leaveFridge() async {
        let leavingId = currentFridgeId
        guard !leavingId.isEmpty else { return }
        // Sent before leaving: once I'm not a member I can't write to the chat.
        if !roommates.isEmpty { post(message(.event, "\(userName) left the fridge."), to: leavingId) }
        do {
            try await db.collection("fridges").document(leavingId).updateData([
                "memberIds": FieldValue.arrayRemove([uid]),
                "memberNames.\(uid)": FieldValue.delete(),
            ])
        } catch {
            report(error)
            return
        }
        fridgeIds.removeAll { $0 == leavingId }
        myFridges.removeAll { $0.id == leavingId }
        if let next = fridgeIds.first {
            attach(fridgeId: next)
            do { try await persistUser() } catch { report(error) }
        } else {
            detach()
            currentFridgeId = ""
            do { try await persistUser() } catch { report(error) }
            phase = .onboarding
        }
    }

    // MARK: - Live data

    private func foodsRef(_ fridgeId: String) -> CollectionReference {
        db.collection("fridges").document(fridgeId).collection("foods")
    }

    private func offersRef(_ fridgeId: String) -> CollectionReference {
        db.collection("fridges").document(fridgeId).collection("offers")
    }

    private func messagesRef(_ fridgeId: String) -> CollectionReference {
        db.collection("fridges").document(fridgeId).collection("messages")
    }

    private func attach(fridgeId: String) {
        detach()
        currentFridgeId = fridgeId
        Task { await loadMyFridges() }
        let fridgeListener = db.collection("fridges").document(fridgeId).addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot, snapshot.exists, var fridge = try? snapshot.data(as: Fridge.self) else { return }
            fridge.id = snapshot.documentID
            Task { @MainActor [fridge] in self?.fridge = fridge }
        }
        let foodsListener = foodsRef(fridgeId).addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot else { return }
            let items: [Food] = snapshot.documents.compactMap { doc in
                guard var food = try? doc.data(as: Food.self) else { return nil }
                food.id = doc.documentID
                return food
            }
            Task { @MainActor in
                guard let self else { return }
                self.foods = items.sorted { $0.expiry < $1.expiry }
                NotificationService.scheduleExpiryReminders(for: self.visibleFoods)
            }
        }
        let offersListener = offersRef(fridgeId)
            .order(by: "createdAt", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot else { return }
                let items: [Offer] = snapshot.documents.compactMap { doc in
                    guard var offer = try? doc.data(as: Offer.self) else { return nil }
                    offer.id = doc.documentID
                    return offer
                }
                Task { @MainActor in
                    guard let self else { return }
                    // Only glow for offers we haven't seen yet, so opening the food clears it for good.
                    let known = Set(self.offers.map(\.id))
                    let newOnes = items.filter { !known.contains($0.id) && $0.recipientIds.contains(self.uid) && $0.claimedById == nil && !$0.dismissedBy.contains(self.uid) }
                    self.highlightedFoodIds.formUnion(newOnes.map(\.foodId))
                    self.offers = items
                }
            }
        let messagesListener = messagesRef(fridgeId)
            .order(by: "createdAt", descending: true)
            .limit(to: 150)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot else { return }
                let items: [ChatMessage] = snapshot.documents.compactMap { doc in
                    guard var message = try? doc.data(as: ChatMessage.self) else { return nil }
                    message.id = doc.documentID
                    return message
                }
                Task { @MainActor in self?.messages = items.reversed() }
            }
        loadChatLastRead(fridgeId)
        listeners = [fridgeListener, foodsListener, offersListener, messagesListener]
    }

    private func detach() {
        listeners.forEach { $0.remove() }
        listeners = []
        fridge = nil
        foods = []
        offers = []
        messages = []
        recipes = []
        recipeSelection = []
        recipesFocus = []
        recipesInventoryKey = ""
        highlightedFoodIds = []
    }

    // MARK: - Derived lists (same rules as Fridge() in App.tsx)

    var roommates: [Member] {
        guard let fridge else { return [] }
        return fridge.memberIds
            .filter { $0 != uid }
            .map { Member(id: $0, name: fridge.memberNames[$0] ?? "Roommate") }
    }

    var visibleFoods: [Food] { foods.filter { $0.isVisible(to: uid) } }

    /// Mine and not shared, expiring or not (the ring color shows how fresh it is).
    /// Living alone there is no Shared shelf, so everything goes here.
    var personalFoods: [Food] {
        guard !roommates.isEmpty else { return visibleFoods }
        return visibleFoods.filter { $0.ownerId == uid && !$0.isShared }
    }

    /// Shared by me or with me, expiring or not. Only shown when the fridge has roommates.
    var sharedFoods: [Food] {
        guard !roommates.isEmpty else { return [] }
        return visibleFoods.filter { $0.isShared }
    }

    /// Anything expiring within 3 days that I can see.
    var expiringFoods: [Food] { visibleFoods.filter { $0.freshness != .fresh } }

    func foods(in category: FridgeCategory) -> [Food] {
        switch category {
        case .personal: return personalFoods
        case .shared: return sharedFoods
        case .expiring: return expiringFoods
        }
    }

    func food(id: String) -> Food? { foods.first { $0.id == id } }

    func memberName(_ id: String) -> String {
        if id == uid { return userName }
        return fridge?.memberNames[id] ?? "Roommate"
    }

    /// Banner on the home screen: an offer sent to me, or a claim on my offer.
    var activeOffer: Offer? {
        offers.first { offer in
            guard !offer.dismissedBy.contains(uid), food(id: offer.foodId) != nil || offer.claimedById != nil else { return false }
            let incoming = offer.recipientIds.contains(uid) && offer.claimedById == nil
            let myOfferClaimed = offer.fromId == uid && offer.claimedById != nil && offer.claimedById != uid
            return incoming || myOfferClaimed
        }
    }

    // MARK: - Mutations

    func addFoods(_ items: [DetectedItem]) async throws {
        guard let fridge else { return }
        let batch = db.batch()
        for item in items where !item.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let quantity = item.parsedQuantity
            let food = Food(
                name: item.name.trimmingCharacters(in: .whitespaces),
                imageData: item.sticker.flatMap { ImageProcessor.stickerBase64($0) },
                expiry: item.expiry,
                amount: quantity.amount,
                fullAmount: max(quantity.amount, 0.01),
                unit: quantity.unit,
                ownerId: uid,
                ownerName: userName,
                sharing: item.sharing,
                sharedWith: item.sharing == .selected ? item.sharedWith : [],
                createdAt: Date()
            )
            try batch.setData(from: food, forDocument: foodsRef(fridge.id).document())
        }
        try await batch.commit()
        // Only food shared with everyone is announced, so private items stay private.
        let shared = items
            .filter { $0.sharing == .everyone }
            .map { $0.name.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !shared.isEmpty && !roommates.isEmpty {
            post(message(.event, "\(userName) added \(Self.list(shared)) to the shared fridge."), to: fridge.id)
        }
    }

    /// "I Used Some" and the post-cooking update. Empty removes the item.
    /// Updates the screen right away, then saves; if the save fails it rolls back and reports why.
    /// `announce: false` skips the chat note (the recipe flow posts one summary instead).
    func setAmount(_ food: Food, amount: Double, announce: Bool = true) async {
        let fridgeId = currentFridgeId
        guard !fridgeId.isEmpty else {
            report(AppError.message("No fridge is open. Try again in a moment."))
            return
        }
        if amount <= 0 {
            await remove(food, announce: announce)
            return
        }
        let current = self.food(id: food.id) ?? food
        let previous = current.amount
        patchLocal(food.id) { $0.amount = amount }
        do {
            try await foodsRef(fridgeId).document(food.id).updateData(["amount": amount])
            if announce && amount < previous && current.sharing == .everyone && !roommates.isEmpty {
                post(message(.event, "\(userName) used some of \(phrase(current)). \(Food.format(amount)) \(current.unit) left."), to: fridgeId)
            }
        } catch {
            patchLocal(food.id) { $0.amount = previous }
            report(error)
        }
    }

    func remove(_ food: Food, announce: Bool = true) async {
        let fridgeId = currentFridgeId
        guard !fridgeId.isEmpty else {
            report(AppError.message("No fridge is open. Try again in a moment."))
            return
        }
        let current = self.food(id: food.id) ?? food
        highlightedFoodIds.remove(food.id)
        do {
            try await foodsRef(fridgeId).document(food.id).delete()
            if announce && current.sharing == .everyone && !roommates.isEmpty {
                post(message(.event, "\(userName) used up \(phrase(current))."), to: fridgeId)
            }
        } catch {
            report(error)
        }
    }

    /// Edit the expiry date after the food is already in the fridge.
    func setExpiry(_ food: Food, date: Date) async {
        let fridgeId = currentFridgeId
        guard !fridgeId.isEmpty else {
            report(AppError.message("No fridge is open. Try again in a moment."))
            return
        }
        let previous = self.food(id: food.id)?.expiry ?? food.expiry
        patchLocal(food.id) { $0.expiry = date }
        do {
            try await foodsRef(fridgeId).document(food.id).updateData(["expiry": Timestamp(date: date)])
        } catch {
            patchLocal(food.id) { $0.expiry = previous }
            report(error)
        }
    }

    private func patchLocal(_ id: String, _ change: (inout Food) -> Void) {
        guard let index = foods.firstIndex(where: { $0.id == id }) else { return }
        change(&foods[index])
        foods.sort { $0.expiry < $1.expiry }
    }

    func setSharing(_ food: Food, sharing: Sharing, with ids: [String]) async {
        guard let fridge else { return }
        try? await foodsRef(fridge.id).document(food.id).updateData([
            "sharing": sharing.rawValue,
            "sharedWith": sharing == .selected ? ids : [],
        ])
    }

    /// "Share it with..." on almost-expired food: share it and notify the chosen roommates.
    func offer(_ food: Food, to recipients: [String], everyone: Bool) async {
        guard let fridge else { return }
        let ids = everyone ? roommates.map(\.id) : recipients
        await setSharing(food, sharing: everyone ? .everyone : .selected, with: ids)
        let offer = Offer(
            foodId: food.id,
            foodName: food.name,
            fromId: uid,
            fromName: userName,
            recipientIds: ids,
            dismissedBy: [],
            claimedById: nil,
            claimedByName: nil,
            createdAt: Date()
        )
        let ref = offersRef(fridge.id).document()
        try? ref.setData(from: offer)
        let who = everyone ? "everyone" : Self.list(ids.map { memberName($0) })
        post(message(.offer, "\(userName) is sharing \(food.name) with \(who). \(food.daysLabel).", offerId: ref.documentID), to: fridge.id)
    }

    /// "I'll take it": the food moves to my personal fridge.
    func claim(_ offer: Offer) async {
        guard let fridge else { return }
        let batch = db.batch()
        batch.updateData([
            "ownerId": uid,
            "ownerName": userName,
            "sharing": Sharing.justMe.rawValue,
            "sharedWith": [String](),
        ], forDocument: foodsRef(fridge.id).document(offer.foodId))
        batch.updateData([
            "claimedById": uid,
            "claimedByName": userName,
            "dismissedBy": FieldValue.arrayUnion([uid]),
        ], forDocument: offersRef(fridge.id).document(offer.id))
        let note = message(.event, "\(userName) took \(offer.fromName)'s \(offer.foodName.lowercased()).")
        try? batch.setData(from: note, forDocument: messagesRef(fridge.id).document())
        highlightedFoodIds.remove(offer.foodId)
        try? await batch.commit()
    }

    // MARK: - Chat

    var unreadChatCount: Int {
        messages.filter { $0.senderId != uid && $0.createdAt > chatLastRead }.count
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        post(message(.text, trimmed), to: currentFridgeId)
    }

    /// "Can I have 2 eggs?" Shows as a card roommates can answer.
    func askFor(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        post(message(.request, trimmed), to: currentFridgeId)
    }

    /// "I've got it" on a roommate's request.
    func fulfill(_ request: ChatMessage) async {
        let fridgeId = currentFridgeId
        guard !fridgeId.isEmpty, request.fulfilledById == nil, request.senderId != uid else { return }
        do {
            try await messagesRef(fridgeId).document(request.id).updateData([
                "fulfilledById": uid,
                "fulfilledByName": userName,
            ])
            post(message(.event, "\(userName) can help \(request.senderName) with that."), to: fridgeId)
        } catch {
            report(error)
        }
    }

    /// One note after cooking instead of one per ingredient.
    func postCooked(_ recipeName: String, used: [Food]) {
        let shared = used.filter { $0.sharing == .everyone }
        guard !shared.isEmpty, !roommates.isEmpty else { return }
        post(message(.event, "\(userName) cooked \(recipeName) with \(Self.list(shared.map { phrase($0) }))."), to: currentFridgeId)
    }

    func markChatRead() {
        let latest = max(messages.last?.createdAt ?? .distantPast, Date())
        guard latest > chatLastRead, !currentFridgeId.isEmpty else { return }
        chatLastRead = latest
        UserDefaults.standard.set(latest.timeIntervalSince1970, forKey: "chatLastRead-\(currentFridgeId)")
    }

    /// A fridge I open for the first time starts with nothing unread.
    private func loadChatLastRead(_ fridgeId: String) {
        let key = "chatLastRead-\(fridgeId)"
        let saved = UserDefaults.standard.double(forKey: key)
        if saved > 0 {
            chatLastRead = Date(timeIntervalSince1970: saved)
        } else {
            chatLastRead = Date()
            UserDefaults.standard.set(chatLastRead.timeIntervalSince1970, forKey: key)
        }
    }

    private func message(_ kind: ChatMessage.Kind, _ text: String, offerId: String? = nil) -> ChatMessage {
        ChatMessage(
            kind: kind,
            text: text,
            senderId: uid,
            senderName: userName,
            offerId: offerId,
            fulfilledById: nil,
            fulfilledByName: nil,
            createdAt: Date()
        )
    }

    private func post(_ message: ChatMessage, to fridgeId: String) {
        guard !fridgeId.isEmpty else { return }
        do {
            try messagesRef(fridgeId).document().setData(from: message)
        } catch {
            report(error)
        }
    }

    /// "the milk" for my food, "Alex's milk" for a roommate's.
    private func phrase(_ food: Food) -> String {
        let name = food.name.lowercased()
        return food.ownerId == uid ? "the \(name)" : "\(food.ownerName)'s \(name)"
    }

    /// "a", "a and b", "a, b and c", "a, b, c +2"
    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2...3: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        default: return items.prefix(3).joined(separator: ", ") + " +\(items.count - 3)"
        }
    }

    func dismiss(_ offer: Offer) async {
        guard let fridge else { return }
        highlightedFoodIds.remove(offer.foodId)
        try? await offersRef(fridge.id).document(offer.id).updateData([
            "dismissedBy": FieldValue.arrayUnion([uid]),
        ])
    }

    // MARK: - Recipes

    /// Regenerates only when foods are added or removed. Changing an amount used to trigger
    /// a full AI round trip every time you opened Recipes.
    private var inventoryKey: String {
        visibleFoods.map(\.id).sorted().joined(separator: ",")
    }

    func loadRecipesIfNeeded() async {
        guard inventoryKey != recipesInventoryKey || recipes.isEmpty else { return }
        await refreshRecipes()
    }

    /// "Make recipes with these": every recipe uses all the picked ingredients.
    func makeRecipes(with ids: [String]) async {
        recipesFocus = ids
        await refreshRecipes()
    }

    /// Back to ideas from the whole fridge.
    func clearRecipeFocus() async {
        recipeSelection = []
        recipesFocus = []
        await refreshRecipes()
    }

    func refreshRecipes() async {
        guard !recipesLoading else { return }
        recipesLoading = true
        recipesError = nil
        recipesInventoryKey = inventoryKey
        let inventory = visibleFoods
        recipesFocus = recipesFocus.filter { id in inventory.contains { $0.id == id } }
        let mustUse = recipesFocus.compactMap { id in inventory.first { $0.id == id } }
        do {
            let result = try await DeepSeekService.recipes(for: inventory, mustUse: mustUse)
            let validIds = Set(inventory.map(\.id))
            recipes = result.map { recipe in
                var copy = recipe
                copy.ingredients = recipe.ingredients.map { ingredient in
                    var item = ingredient
                    // If the AI didn't copy the id correctly, match by name so the fridge still gets updated.
                    if let id = item.foodId, validIds.contains(id) { return item }
                    item.foodId = Self.matchFood(named: item.name, in: inventory)?.id
                    return item
                }
                return copy
            }
        } catch {
            recipesError = Self.friendly(error)
        }
        recipesLoading = false
    }

    // MARK: - Helpers

    private static func makeInviteCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in letters.randomElement()! })
    }

    private func report(_ error: Error) {
        lastError = Self.friendly(error)
    }

    /// "Milk" matches "Oat Milk", "eggs" matches "Egg", but "egg" does not match "Eggplant".
    static func matchFood(named name: String, in foods: [Food]) -> Food? {
        let target = words(name)
        guard !target.isEmpty else { return nil }
        if let exact = foods.first(where: { words($0.name) == target }) { return exact }
        return foods.first { food in
            let candidate = words(food.name)
            return !candidate.isEmpty && (candidate.isSubset(of: target) || target.isSubset(of: candidate))
        }
    }

    private static func words(_ text: String) -> Set<String> {
        let parts = text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 1 }
        return Set(parts.map { word in
            if word.hasSuffix("ies") && word.count > 4 { return String(word.dropLast(3)) + "y" }      // berries → berry
            if ["oes", "xes", "ches", "shes"].contains(where: { word.hasSuffix($0) }) { return String(word.dropLast(2)) } // tomatoes → tomato
            if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 3 { return String(word.dropLast()) } // apples → apple
            return word
        })
    }

    static func friendly(_ error: Error) -> String {
        if let appError = error as? AppError, case .message(let text) = appError { return text }
        return error.localizedDescription
    }
}

enum AppError: Error {
    case message(String)
}

enum FridgeCategory: String, Hashable {
    case personal, shared, expiring

    var title: String {
        switch self {
        case .personal: return "Personal"
        case .shared: return "Shared"
        case .expiring: return "Almost Expired"
        }
    }
}
