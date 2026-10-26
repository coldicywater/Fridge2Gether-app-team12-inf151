import SwiftUI

/// App shell: tab content + floating bottom nav + food detail sheet + scan flow + profile.
struct MainView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: MainTab = .fridge
    @State private var fridgePath: [FridgeCategory] = []
    @State private var recipesPath: [RecipeRoute] = []
    @State private var detailFood: Food?
    @State private var scanning = false
    @State private var showProfile = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .fridge:
                    NavigationStack(path: $fridgePath) {
                        HomeView(onFood: open, onProfile: { showProfile = true }, onCategory: { fridgePath.append($0) })
                            .navigationDestination(for: FridgeCategory.self) { category in
                                CategoryView(category: category, onFood: open)
                            }
                    }
                case .recipes:
                    NavigationStack(path: $recipesPath) {
                        RecipesView(path: $recipesPath, onProfile: { showProfile = true })
                            .navigationDestination(for: RecipeRoute.self) { route in
                                RecipeRouteView(route: route, path: $recipesPath, onGoHome: goHome)
                            }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: showsNav ? 96 : 0) }

            if showsNav {
                BottomNav(tab: $tab, onScan: { scanning = true })
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $detailFood) { food in
            FoodDetailSheet(foodId: food.id, onWhatCanIMake: {
                detailFood = nil
                tab = .recipes
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
        .fullScreenCover(isPresented: $scanning) {
            ScanFlowView(onDone: {
                scanning = false
                tab = .fridge
                fridgePath = []
            })
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
                .presentationDetents([.medium, .large])
        }
    }

    /// Cooking mode and the post-cooking update hide the nav, like in the prototype.
    private var showsNav: Bool {
        if tab == .recipes, let last = recipesPath.last {
            switch last {
            case .cooking, .update: return false
            case .detail: return true
            }
        }
        return true
    }

    private func open(_ food: Food) {
        store.highlightedFoodIds.remove(food.id)
        detailFood = food
    }

    private func goHome() {
        recipesPath = []
        fridgePath = []
        tab = .fridge
    }
}

// MARK: - Home

struct HomeView: View {
    @Environment(AppStore.self) private var store
    let onFood: (Food) -> Void
    let onProfile: () -> Void
    let onCategory: (FridgeCategory) -> Void

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "GOOD MORNING" : (hour < 18 ? "GOOD AFTERNOON" : "GOOD EVENING")
        return "\(part), \(store.userName.uppercased())"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ScreenHeader(eyebrow: greeting, title: "My Fridge", userName: store.userName, onProfile: onProfile)
                    .padding(.bottom, 4)

                if let offer = store.activeOffer {
                    OfferBanner(offer: offer, onView: {
                        if let food = store.food(id: offer.foodId) { onFood(food) }
                    })
                }

                if store.visibleFoods.isEmpty {
                    HStack(spacing: 9) {
                        Image(systemName: "camera")
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Your fridge is empty!").font(AppFont.rounded(13, .black)).foregroundStyle(Palette.ink)
                            Text("Scan your first groceries to get started.").font(AppFont.rounded(12, .semibold))
                        }
                    }
                    .foregroundStyle(Color(hex: 0x58716B))
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(RoundedRectangle(cornerRadius: 17).fill(Color.white.opacity(0.5)))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color(hex: 0x85A49A), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                } else if !store.expiringFoods.isEmpty {
                    ExpiringWarning(count: store.expiringFoods.count) { onCategory(.expiring) }
                }

                FridgeView(onFood: onFood, onCategory: onCategory)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Replaces "your fridge is looking fresh & happy" with an expiry warning (per team notes).
struct ExpiringWarning: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Text("\(count)")
                    .font(AppFont.rounded(19, .black))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color(hex: 0xF8CF61)))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 1) {
                    Text(count == 1 ? "1 item expires soon" : "\(count) items expire soon")
                        .font(AppFont.rounded(15, .black))
                    Text("Tap to see what to use first").font(AppFont.rounded(12, .semibold)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 13)
            .frame(height: 64)
            .cartoonCard(fill: Palette.expiringYellow, radius: 19)
        }
        .buttonStyle(.plain)
    }
}

/// "Alex shared oat milk with you!" / "Food rescued!"
struct OfferBanner: View {
    @Environment(AppStore.self) private var store
    let offer: Offer
    let onView: () -> Void

    private var incoming: Bool { offer.claimedById == nil }

    var body: some View {
        HStack(spacing: 9) {
            Text(String((incoming ? offer.fromName : offer.claimedByName ?? "R").prefix(1)).uppercased())
                .font(AppFont.rounded(15, .black))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: 0xDD8D66)))
                .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 2) {
                if incoming {
                    Text("\(offer.fromName) shared \(offer.foodName.lowercased()) with you!")
                        .font(AppFont.rounded(13, .black))
                    Text("It expires soon. Tap to view.").font(AppFont.rounded(11, .semibold)).foregroundStyle(Palette.muted)
                } else {
                    Text("Food rescued!").font(AppFont.rounded(13, .black))
                    Text("\(offer.claimedByName ?? "A roommate") took your \(offer.foodName.lowercased()).")
                        .font(AppFont.rounded(11, .semibold)).foregroundStyle(Palette.muted)
                }
            }
            .lineLimit(2)
            Spacer(minLength: 4)
            if incoming {
                Button("I'll Take It") { Task { await store.claim(offer) } }
                    .font(AppFont.rounded(11, .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x72B88A)))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.ink, lineWidth: 2))
            }
            Button {
                Task { await store.dismiss(offer) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.muted)
            }
            .accessibilityLabel("Dismiss")
        }
        .foregroundStyle(Palette.ink)
        .padding(11)
        .cartoonCard(fill: incoming ? Color(hex: 0xFFF2C9) : Color(hex: 0xD9EFD5), radius: 18)
        .contentShape(Rectangle())
        .onTapGesture { if incoming { onView() } }
    }
}

// MARK: - Category list

struct CategoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let category: FridgeCategory
    let onFood: (Food) -> Void

    private var background: Color {
        switch category {
        case .personal: return Color(hex: 0xFDFBF5)
        case .shared: return Color(hex: 0xEEF8F3)
        case .expiring: return Palette.expiringYellow
        }
    }

    var body: some View {
        let foods = store.foods(in: category)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundBackButton { dismiss() }
                    .padding(.bottom, 16)
                Text("YOUR FRIDGE").eyebrowStyle()
                Text(category.title)
                    .font(AppFont.rounded(30, .black))
                    .padding(.top, 2)
                Text("\(foods.count) \(foods.count == 1 ? "ingredient" : "ingredients")")
                    .font(AppFont.rounded(12, .heavy))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 5)
                    .padding(.bottom, 18)

                VStack(spacing: 10) {
                    ForEach(foods) { food in
                        Button { onFood(food) } label: { row(food) }
                            .buttonStyle(.plain)
                    }
                    if foods.isEmpty {
                        Text(category == .expiring ? "Nothing expiring. Nice!" : "Nothing here yet.")
                            .font(AppFont.hand(18))
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .foregroundStyle(Palette.ink)
        }
        .background(LinearGradient(colors: [background, Palette.cream], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ food: Food) -> some View {
        HStack(spacing: 8) {
            StickerView(food: food, size: .small, showLabel: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name).font(AppFont.rounded(15, .black))
                Text("Expires \(food.dateLabel) · \(food.daysLabel)")
                    .font(AppFont.rounded(11, .semibold))
                    .foregroundStyle(Color(hex: 0x70807B))
                if food.ownerId != store.uid {
                    Text("From \(food.ownerName)")
                        .font(AppFont.rounded(10, .heavy))
                        .foregroundStyle(Palette.sharedText)
                }
            }
            Spacer(minLength: 4)
            Text(food.quantityLabel)
                .font(AppFont.rounded(10, .black))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 72)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color(hex: 0xEEF0EB)))
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(minHeight: 83)
        .cartoonCard(radius: 17, shadow: 2)
    }
}
