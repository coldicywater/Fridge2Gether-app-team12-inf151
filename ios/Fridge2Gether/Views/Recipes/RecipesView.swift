import SwiftUI

enum RecipeRoute: Hashable {
    case detail(Recipe)
    case cooking(Recipe)
    case update(Recipe)
}

/// "Cook it soon": expiring items first, then AI recipes made from what's in the fridge.
struct RecipesView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [RecipeRoute]
    let onProfile: () -> Void
    let onChat: () -> Void
    @State private var query = ""

    private var filtered: [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.recipes }
        return store.recipes.filter { recipe in
            ([recipe.name] + recipe.ingredients.map(\.name)).joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "RECIPES FOR YOUR FRIDGE", title: "Cook it soon", userName: store.userName, onProfile: onProfile,
                             onChat: onChat, unread: store.unreadChatCount)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                // Pick ingredients to cook with
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Pick what to cook with", trailing: selected.isEmpty ? nil : "\(selected.count) picked")
                    if store.visibleFoods.isEmpty {
                        Text("Your fridge is empty")
                            .font(AppFont.hand(16))
                            .foregroundStyle(Color(hex: 0x5F7770))
                            .padding(.vertical, 6)
                    } else {
                        Text("Tap ingredients, then make recipes that use all of them.")
                            .font(AppFont.rounded(11, .semibold))
                            .foregroundStyle(Color(hex: 0x5F7770))
                        if !store.expiringFoods.isEmpty {
                            pickRow("USE THESE FIRST", foods: store.expiringFoods)
                        }
                        let fresh = store.visibleFoods.filter { $0.freshness == .fresh }
                        if !fresh.isEmpty {
                            pickRow("ALSO IN YOUR FRIDGE", foods: fresh)
                        }
                        if !selected.isEmpty {
                            HStack(spacing: 8) {
                                Button {
                                    Task { await store.makeRecipes(with: selectedInOrder) }
                                } label: {
                                    Label("Make recipes with \(selected.count == 1 ? "it" : "these \(selected.count)")", systemImage: "sparkles")
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(store.recipesLoading)
                                Button("Clear") { store.recipeSelection = [] }
                                    .buttonStyle(SecondaryButtonStyle())
                                    .frame(width: 84)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(EdgeInsets(top: 13, leading: 18, bottom: 12, trailing: 18))
                .background(Color(hex: 0xDFF1EA))
                .overlay(alignment: .top) { Rectangle().fill(Palette.ink).frame(height: 2) }
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 2) }

                // Made for your fridge
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text(focusTitle)
                            .font(AppFont.rounded(16, .black))
                            .lineLimit(2)
                        Spacer()
                        Button {
                            Task { await store.refreshRecipes() }
                        } label: {
                            Label("New ideas", systemImage: "arrow.clockwise")
                                .font(AppFont.rounded(11, .black))
                                .foregroundStyle(Palette.muted)
                        }
                        .disabled(store.recipesLoading)
                    }
                    if !store.recipesFocus.isEmpty {
                        Button {
                            Task { await store.clearRecipeFocus() }
                        } label: {
                            Label("Show ideas for the whole fridge", systemImage: "xmark.circle")
                                .font(AppFont.rounded(11, .black))
                                .foregroundStyle(Palette.sharedText)
                        }
                        .disabled(store.recipesLoading)
                    }
                    if store.recipesLoading && !store.recipes.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().tint(Palette.ink)
                            Text("Making new recipes...")
                                .font(AppFont.rounded(12, .bold))
                                .foregroundStyle(Palette.muted)
                        }
                    }

                    HStack(spacing: 7) {
                        Image(systemName: "sparkles").font(.system(size: 14))
                        TextField("Search recipes or ingredients", text: $query)
                            .font(AppFont.rounded(13, .semibold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 11)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 13).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(hex: 0xB8C4BF), lineWidth: 1.5))

                    if store.recipesLoading && store.recipes.isEmpty {
                        VStack(spacing: 10) {
                            ProgressView().tint(Palette.ink)
                            Text("Cooking up ideas from your fridge...")
                                .font(AppFont.rounded(13, .bold))
                                .foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else if let error = store.recipesError, store.recipes.isEmpty {
                        VStack(spacing: 10) {
                            Text(error)
                                .font(AppFont.rounded(13, .semibold))
                                .foregroundStyle(Palette.danger)
                                .multilineTextAlignment(.center)
                            Button("Try again") { Task { await store.refreshRecipes() } }
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(width: 160)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                    ForEach(filtered) { recipe in
                        Button { path.append(.detail(recipe)) } label: { RecipeCard(recipe: recipe) }
                            .buttonStyle(.plain)
                    }
                    .opacity(store.recipesLoading ? 0.5 : 1)
                }
                .padding(EdgeInsets(top: 15, leading: 18, bottom: 20, trailing: 18))
            }
            .padding(.top, 8)
            .foregroundStyle(Palette.ink)
        }
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.loadRecipesIfNeeded() }
    }

    /// Picked ingredients that are still in the fridge.
    private var selected: Set<String> {
        store.recipeSelection.intersection(store.visibleFoods.map(\.id))
    }

    /// Same order as the fridge (soonest to expire first).
    private var selectedInOrder: [String] {
        store.visibleFoods.map(\.id).filter { selected.contains($0) }
    }

    private var focusTitle: String {
        let names = store.recipesFocus.compactMap { store.food(id: $0)?.name }
        guard !names.isEmpty else { return "Made for your fridge" }
        return "Made with " + names.joined(separator: ", ")
    }

    private func pickRow(_ title: String, foods: [Food]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppFont.rounded(9, .black))
                .tracking(1)
                .foregroundStyle(Color(hex: 0x5F7770))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(foods) { food in
                        let picked = selected.contains(food.id)
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                if picked { store.recipeSelection.remove(food.id) } else { store.recipeSelection.insert(food.id) }
                            }
                        } label: {
                            StickerView(food: food, size: .small)
                                .overlay(alignment: .topTrailing) {
                                    if picked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Circle().fill(Palette.green))
                                            .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
                                            .offset(x: 2, y: -2)
                                    }
                                }
                                .scaleEffect(picked ? 1.06 : 1)
                                .offset(y: picked ? -2 : 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(picked ? "\(food.name), picked" : food.name)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
        }
    }

    private func sectionTitle(_ title: String, trailing: String?) -> some View {
        HStack {
            Text(title).font(AppFont.rounded(16, .black))
            Spacer()
            if let trailing {
                Text(trailing).font(AppFont.rounded(11, .black)).foregroundStyle(Color(hex: 0x71827D))
            }
        }
    }
}

/// Colored tile with a big emoji, standing in for the recipe photo.
struct RecipeArt: View {
    let recipe: Recipe
    var emojiSize: CGFloat = 52

    private var tint: Color {
        let colors = [Color(hex: 0xFFE7B8), Color(hex: 0xDFF1EA), Color(hex: 0xFCD9CF), Color(hex: 0xE3E9F8), Color(hex: 0xF3F0C6)]
        let index = abs(recipe.name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % colors.count
        return colors[index]
    }

    var body: some View {
        ZStack {
            tint
            Circle().fill(.white.opacity(0.55)).padding(14)
            Text(recipe.emoji).font(.system(size: emojiSize))
        }
    }
}

struct RecipeCard: View {
    @Environment(AppStore.self) private var store
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 0) {
            RecipeArt(recipe: recipe)
                .frame(width: 120)
                .overlay(alignment: .trailing) { Rectangle().fill(Palette.ink).frame(width: 2) }
            VStack(alignment: .leading, spacing: 6) {
                Label("\(recipe.minutes) min", systemImage: "clock")
                    .font(AppFont.rounded(11, .black))
                    .foregroundStyle(Color(hex: 0x6C7E79))
                Text(recipe.name)
                    .font(AppFont.rounded(16, .black))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                FlowTags(tags: recipe.ingredients.map { ($0.name, store.food(id: $0.foodId ?? "") != nil) })
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 137)
        .foregroundStyle(Palette.ink)
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .cartoonCard(radius: 19)
    }
}

/// Small ingredient chips; green when it's in the fridge.
struct FlowTags: View {
    let tags: [(String, Bool)]

    var body: some View {
        let shown = Array(tags.prefix(4))
        HStack(spacing: 4) {
            ForEach(shown.indices, id: \.self) { i in
                Text(shown[i].0)
                    .font(AppFont.rounded(9, .black))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundStyle(shown[i].1 ? Color(hex: 0x317457) : Color(hex: 0x76817E))
                    .background(RoundedRectangle(cornerRadius: 8).fill(shown[i].1 ? Color(hex: 0xD5EEDC) : Color(hex: 0xE3E5E1)))
            }
        }
    }
}
