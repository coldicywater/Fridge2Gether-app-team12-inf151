import SwiftUI

/// The blue fridge with Personal / Shared / Almost Expired shelves (status-fridge in the prototype).
struct FridgeView: View {
    @Environment(AppStore.self) private var store
    let onFood: (Food) -> Void
    let onCategory: (FridgeCategory) -> Void

    var body: some View {
        VStack(spacing: 7) {
            zone(.personal, subtitle: "just yours", foods: store.personalFoods,
                 fill: Palette.shelfWhite, titleColor: Palette.ink)
                .frame(height: 145)
            zone(.shared, subtitle: "roommates can use", foods: store.sharedFoods,
                 fill: Palette.sharedGreen, titleColor: Palette.sharedText)
                .frame(height: 145)
            zone(.expiring, subtitle: "use these soon", foods: store.expiringFoods,
                 fill: Palette.expiringYellow, titleColor: Palette.expiringText,
                 border: Palette.expiringBorder, inset: Palette.expiringInset)
                .frame(minHeight: 170)
        }
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 22, trailing: 15))
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .padding(8)
        )
        .background(UnevenRoundedRectangle(topLeadingRadius: 35, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 35).fill(Palette.fridgeBlue))
        .overlay(UnevenRoundedRectangle(topLeadingRadius: 35, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 35).stroke(Palette.ink, lineWidth: 4))
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 35, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 35)
                .fill(Palette.ink).offset(x: 7, y: 8)
        )
        .background(alignment: .bottom) {
            HStack {
                leg
                Spacer()
                leg
            }
            .padding(.horizontal, 40)
            .offset(y: 13)
        }
    }

    private var leg: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9)
            .fill(Palette.leg)
            .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9).stroke(Palette.ink, lineWidth: 3))
            .frame(width: 36, height: 14)
    }

    private func zone(_ category: FridgeCategory, subtitle: String, foods: [Food], fill: Color, titleColor: Color,
                      border: Color = Palette.ink, inset: Color? = nil) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 15).fill(fill)
            if let inset {
                RoundedRectangle(cornerRadius: 13).stroke(inset, lineWidth: 3).padding(3)
            }
            // Shelf lip at the bottom.
            VStack {
                Spacer()
                Rectangle().fill(.white).frame(height: 7)
                    .overlay(alignment: .top) { Rectangle().fill(border).frame(height: 3) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(category.title)
                        .font(AppFont.hand(19))
                        .foregroundStyle(titleColor)
                    Spacer()
                    Text(subtitle.uppercased())
                        .font(AppFont.rounded(8, .black))
                        .tracking(0.4)
                        .foregroundStyle(Color(hex: 0x748681))
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                Spacer(minLength: 0)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(foods) { food in
                            Button { onFood(food) } label: {
                                StickerView(
                                    food: food,
                                    highlighted: store.highlightedFoodIds.contains(food.id),
                                    badge: food.ownerId != store.uid ? food.ownerName : nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 11)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(border, lineWidth: 3))
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .onTapGesture { onCategory(category) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(category.title), \(foods.count) items")
    }
}
