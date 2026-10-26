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
    var foods: [Food] = []
    var offers: [Offer] = []

    var recipes: [Recipe] = []
    var recipesLoading = false
    var recipesError: String?
    private var recipesInventoryKey = ""

    /// Food ids that were just shared with me; they glow on the fridge until opened.
    var highlightedFoodIds: Set<String> = []

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
            if let data = snapshot.data(),
               let name = data["name"] as? String,
               let fridgeId = data["fridgeId"] as? String, !fridgeId.isEmpty {
                userName = name
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
        try await db.collection("users").document(uid).setData(["name": name, "fridgeId": ref.documentID])
        userName = name
        attach(fridgeId: ref.documentID)
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
        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([uid]),
            "memberNames.\(uid)": name,
        ])
        try await db.collection("users").document(uid).setData(["name": name, "fridgeId": doc.documentID])
        userName = name
        attach(fridgeId: doc.documentID)
        phase = .ready
        NotificationService.requestPermission()
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

    func leaveFridge() async {
        guard let fridge else { return }
        try? await db.collection("fridges").document(fridge.id).updateData([
            "memberIds": FieldValue.arrayRemove([uid]),
            "memberNames.\(uid)": FieldValue.delete(),
        ])
        try? await db.collection("users").document(uid).delete()
        detach()
        phase = .onboarding
    }

    // MARK: - Live data

    private func foodsRef(_ fridgeId: String) -> CollectionReference {
        db.collection("fridges").document(fridgeId).collection("foods")
    }

    private func offersRef(_ fridgeId: String) -> CollectionReference {
        db.collection("fridges").document(fridgeId).collection("offers")
    }

    private func attach(fridgeId: String) {
        detach()
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
        listeners = [fridgeListener, foodsListener, offersListener]
    }

    private func detach() {
        listeners.forEach { $0.remove() }
        listeners = []
        fridge = nil
        foods = []
        offers = []
        recipes = []
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

    /// Fresh, mine, not shared.
    var personalFoods: [Food] { visibleFoods.filter { $0.freshness == .fresh && $0.ownerId == uid && !$0.isShared } }

    /// Fresh and shared (by me, or with me).
    var sharedFoods: [Food] { visibleFoods.filter { $0.freshness == .fresh && $0.isShared } }

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
    }

    /// "I Used Some" and the post-cooking update. Empty removes the item.
    func setAmount(_ food: Food, amount: Double) async {
        guard let fridge else { return }
        if amount <= 0 {
            await remove(food)
            return
        }
        try? await foodsRef(fridge.id).document(food.id).updateData(["amount": amount])
    }

    func remove(_ food: Food) async {
        guard let fridge else { return }
        highlightedFoodIds.remove(food.id)
        try? await foodsRef(fridge.id).document(food.id).delete()
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
        try? offersRef(fridge.id).document().setData(from: offer)
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
        highlightedFoodIds.remove(offer.foodId)
        try? await batch.commit()
    }

    func dismiss(_ offer: Offer) async {
        guard let fridge else { return }
        highlightedFoodIds.remove(offer.foodId)
        try? await offersRef(fridge.id).document(offer.id).updateData([
            "dismissedBy": FieldValue.arrayUnion([uid]),
        ])
    }

    // MARK: - Recipes

    func loadRecipesIfNeeded() async {
        let key = visibleFoods.map { "\($0.id):\($0.amount)" }.joined(separator: ",")
        guard key != recipesInventoryKey || recipes.isEmpty else { return }
        await refreshRecipes()
    }

    func refreshRecipes() async {
        guard !recipesLoading else { return }
        recipesLoading = true
        recipesError = nil
        recipesInventoryKey = visibleFoods.map { "\($0.id):\($0.amount)" }.joined(separator: ",")
        do {
            let result = try await DeepSeekService.recipes(for: visibleFoods)
            let validIds = Set(visibleFoods.map(\.id))
            recipes = result.map { recipe in
                var copy = recipe
                copy.ingredients = recipe.ingredients.map { ingredient in
                    var item = ingredient
                    if let id = item.foodId, !validIds.contains(id) { item.foodId = nil }
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
