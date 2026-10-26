import SwiftUI

struct RecipeRouteView: View {
    let route: RecipeRoute
    @Binding var path: [RecipeRoute]
    let onGoHome: () -> Void

    var body: some View {
        Group {
            switch route {
            case .detail(let recipe): RecipeDetailView(recipe: recipe, path: $path)
            case .cooking(let recipe): CookingView(recipe: recipe, path: $path)
            case .update(let recipe): UpdateIngredientsView(recipe: recipe, onGoHome: onGoHome)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Detail

struct RecipeDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @Binding var path: [RecipeRoute]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RecipeArt(recipe: recipe, emojiSize: 96)
                    .frame(height: 245)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }

                VStack(alignment: .leading, spacing: 0) {
                    Text("MADE FOR YOUR FRIDGE").eyebrowStyle()
                    Text(recipe.name)
                        .font(AppFont.rounded(28, .black))
                        .padding(.top, 2)
                        .padding(.bottom, 9)
                    HStack(spacing: 9) {
                        metaChip(icon: "clock", text: "\(recipe.minutes) min")
                        metaChip(icon: "person.2", text: "\(recipe.servings) servings")
                    }

                    heading("What you’ll need")
                    VStack(spacing: 6) {
                        ForEach(recipe.ingredients.indices, id: \.self) { i in
                            ingredientRow(recipe.ingredients[i])
                        }
                    }

                    heading("Instructions")
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recipe.steps.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 9) {
                                Text("\(i + 1)")
                                    .font(AppFont.hand(17))
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Palette.yellow))
                                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                                Text(recipe.steps[i])
                                    .font(AppFont.rounded(14, .semibold))
                                    .lineSpacing(3)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    Button("Start Cooking") { path.append(.cooking(recipe)) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(recipe.steps.isEmpty)
                        .padding(.top, 20)
                }
                .padding(EdgeInsets(top: 18, leading: 20, bottom: 20, trailing: 20))
            }
            .foregroundStyle(Palette.ink)
        }
        .background(ScreenBackground())
        .overlay(alignment: .topLeading) {
            RoundBackButton { dismiss() }
                .padding(.leading, 18)
                .padding(.top, 10)
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(AppFont.rounded(16, .black))
            .padding(.top, 22)
            .padding(.bottom, 9)
    }

    private func metaChip(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(AppFont.rounded(11, .black))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xE1EEE8)))
    }

    private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
        let available = store.food(id: ingredient.foodId ?? "") != nil
        return HStack(spacing: 9) {
            Image(systemName: available ? "checkmark" : "minus")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(available ? Color(hex: 0x317457) : Color(hex: 0x8C9692))
                .frame(width: 22, height: 22)
                .background(Circle().fill(available ? Color(hex: 0xD6EDDF) : Color(hex: 0xECEBE5)))
            VStack(alignment: .leading, spacing: 1) {
                Text(ingredient.name).font(AppFont.rounded(14, .black))
                Text("\(ingredient.amount.isEmpty ? "" : ingredient.amount + " · ")\(available ? "In your fridge" : "Missing")")
                    .font(AppFont.rounded(11, .heavy))
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 48)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xCCD5D0), lineWidth: 1.5))
    }
}

// MARK: - Cooking mode

struct CookingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @Binding var path: [RecipeRoute]
    @State private var step = 0

    private var heroFood: Food? {
        recipe.ingredients.compactMap { store.food(id: $0.foodId ?? "") }.first
    }

    var body: some View {
        let isLast = step >= recipe.steps.count - 1
        VStack(spacing: 0) {
            HStack {
                RoundBackButton { dismiss() }
                Spacer()
            }
            .padding(.bottom, 24)

            Text("STEP \(step + 1) OF \(recipe.steps.count)").eyebrowStyle()
                .padding(.bottom, 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white)
                    Capsule().fill(Palette.yellow)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(max(recipe.steps.count, 1)))
                }
                .overlay(Capsule().stroke(Palette.ink, lineWidth: 1.5))
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.25), value: step)

            Spacer(minLength: 30)
            Group {
                if let heroFood {
                    StickerView(food: heroFood, size: .large)
                } else {
                    Text(recipe.emoji).font(.system(size: 80))
                }
            }
            .scaleEffect(1.2)
            .padding(.bottom, 30)

            Text(recipe.steps.indices.contains(step) ? recipe.steps[step] : "")
                .font(AppFont.rounded(26, .black))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 12)
                .id(step)
                .transition(.opacity)
            Text("Take your time. Your fridge will only update after you confirm what’s left.")
                .font(AppFont.rounded(13, .semibold))
                .foregroundStyle(Color(hex: 0x62736F))
                .multilineTextAlignment(.center)
            Spacer(minLength: 30)

            HStack(spacing: 9) {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(step == 0)
                    .opacity(step == 0 ? 0.4 : 1)
                    .frame(maxWidth: 130)
                Button(isLast ? "Finish Cooking" : "Next Step") {
                    if isLast {
                        path.append(.update(recipe))
                    } else {
                        withAnimation { step += 1 }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .foregroundStyle(Palette.ink)
        .background(
            LinearGradient(colors: [Color(hex: 0xDFF1E9), Color(hex: 0xF9F4E8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Update ingredients used

struct UpdateIngredientsView: View {
    @Environment(AppStore.self) private var store
    let recipe: Recipe
    let onGoHome: () -> Void
    @State private var portions: [String: Double] = [:]
    @State private var saving = false

    private var fridgeFoods: [Food] {
        var seen = Set<String>()
        return recipe.ingredients.compactMap { ingredient in
            guard let id = ingredient.foodId, !seen.contains(id), let food = store.food(id: id) else { return nil }
            seen.insert(id)
            return food
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("ONE LAST THING").eyebrowStyle()
                Text("Update Ingredients Used")
                    .font(AppFont.rounded(27, .black))
                    .padding(.top, 3)
                    .padding(.bottom, 5)
                Text("Set how much is left. Nothing changes until you save.")
                    .font(AppFont.rounded(13, .semibold))
                    .foregroundStyle(Color(hex: 0x62736F))
                    .padding(.bottom, 16)

                if fridgeFoods.isEmpty {
                    Text("This recipe didn’t use anything from your fridge.")
                        .font(AppFont.hand(17))
                        .foregroundStyle(Palette.muted)
                        .padding(.vertical, 20)
                }

                VStack(spacing: 10) {
                    ForEach(fridgeFoods) { food in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                StickerView(food: food, size: .small, showLabel: false)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name).font(AppFont.rounded(15, .black))
                                    Text("\(food.quantityLabel) before cooking")
                                        .font(AppFont.rounded(11, .semibold))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                            PortionSelector(
                                value: Binding(
                                    get: { portions[food.id] ?? PortionSelector.snap(food.amount / max(food.fullAmount, 0.01)) },
                                    set: { portions[food.id] = $0 }
                                ),
                                compact: true
                            )
                        }
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xBFCAC5), lineWidth: 1.5))
                    }
                }

                Button("Save ingredient updates") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving)
                    .padding(.top, 14)
                Button("Save later · Return to fridge", action: onGoHome)
                    .font(AppFont.rounded(13, .black))
                    .foregroundStyle(Color(hex: 0x367D64))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
            .padding(.horizontal, 18)
            .padding(.top, 40)
            .padding(.bottom, 30)
            .foregroundStyle(Palette.ink)
        }
        .background(ScreenBackground())
    }

    private func save() {
        saving = true
        let updates = fridgeFoods.compactMap { food -> (Food, Double)? in
            guard let portion = portions[food.id] else { return nil }
            return (food, (food.fullAmount * portion * 100).rounded() / 100)
        }
        Task {
            for (food, amount) in updates {
                await store.setAmount(food, amount: amount)
            }
            saving = false
            onGoHome()
        }
    }
}
