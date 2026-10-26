import SwiftUI

// MARK: - Food sticker

/// The round, slightly tilted food photo with a white (or yellow/coral) ring and a name tag.
struct StickerView: View {
    enum Size {
        case regular, small, large

        var image: CGSize {
            switch self {
            case .regular: return CGSize(width: 72, height: 67)
            case .small: return CGSize(width: 57, height: 53)
            case .large: return CGSize(width: 100, height: 96)
            }
        }
        var ring: CGFloat { self == .small ? 4 : (self == .large ? 6 : 5) }
        var font: CGFloat { self == .small ? 8 : 9 }
        var width: CGFloat { self == .small ? 64 : (self == .large ? 108 : 84) }
    }

    let name: String
    let image: UIImage?
    var freshness: Freshness = .fresh
    var size: Size = .regular
    var showLabel = true
    var highlighted = false
    var badge: String?

    init(food: Food, size: Size = .regular, showLabel: Bool = true, highlighted: Bool = false, badge: String? = nil) {
        self.name = food.name
        self.image = food.image
        self.freshness = food.freshness
        self.size = size
        self.showLabel = showLabel
        self.highlighted = highlighted
        self.badge = badge
    }

    init(name: String, image: UIImage?, size: Size = .regular, showLabel: Bool = true) {
        self.name = name
        self.image = image
        self.size = size
        self.showLabel = showLabel
    }

    private var ringColor: Color {
        switch freshness {
        case .fresh: return .white
        case .soon: return Palette.soonYellow
        case .urgent: return Palette.coral
        }
    }

    @State private var glow = false

    var body: some View {
        VStack(spacing: -3) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.white
                        Text(String(name.prefix(1)).uppercased())
                            .font(AppFont.hand(size.image.height * 0.5))
                            .foregroundStyle(Palette.green)
                    }
                }
            }
            .frame(width: size.image.width, height: size.image.height)
            .clipShape(StickerBlob())
            .overlay(StickerBlob().stroke(ringColor, lineWidth: size.ring * 2).clipShape(StickerBlob()))
            .background(StickerBlob().fill(.white))
            .shadow(color: Color(hex: 0x1B322C, opacity: highlighted && glow ? 0 : 0.3), radius: 3, y: 2)
            .shadow(color: highlighted ? Color(hex: 0x68B990).opacity(glow ? 1 : 0.2) : .clear, radius: glow ? 8 : 2)
            .rotationEffect(.degrees(-2))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(String(badge.prefix(1)).uppercased())
                        .font(AppFont.rounded(9, .black))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Palette.roommate))
                        .overlay(Circle().stroke(Palette.ink, lineWidth: 1.5))
                        .offset(x: 4, y: -2)
                } else if highlighted {
                    Text("✦")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0xD99D16))
                        .offset(x: 4, y: -6)
                }
            }

            if showLabel {
                Text(name)
                    .font(AppFont.rounded(size.font, .black))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().stroke(Palette.ink, lineWidth: 1.5))
                    .frame(maxWidth: size.width)
            }
        }
        .frame(width: size.width)
        .onAppear {
            guard highlighted else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// Slightly lumpy circle (border-radius: 43% 52% 42% 48%).
struct StickerBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.47, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.50), control1: CGPoint(x: w * 0.80, y: 0), control2: CGPoint(x: w, y: h * 0.20))
        p.addCurve(to: CGPoint(x: w * 0.52, y: h), control1: CGPoint(x: w, y: h * 0.82), control2: CGPoint(x: w * 0.80, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.52), control1: CGPoint(x: w * 0.20, y: h), control2: CGPoint(x: 0, y: h * 0.80))
        p.addCurve(to: CGPoint(x: w * 0.47, y: 0), control1: CGPoint(x: 0, y: h * 0.18), control2: CGPoint(x: w * 0.18, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Header

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let userName: String
    let onProfile: () -> Void

    private var initials: String {
        let parts = userName.split(separator: " ").compactMap(\.first)
        let text = String(parts.prefix(2)).uppercased()
        return text.isEmpty ? "ME" : text
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow).eyebrowStyle()
                Text(title)
                    .font(AppFont.rounded(30, .black))
                    .tracking(-1.2)
            }
            Spacer()
            Button(action: onProfile) {
                Text(initials)
                    .font(AppFont.rounded(13, .black))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.avatar))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .background(Circle().fill(Palette.ink).offset(y: 2))
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(Color(hex: 0x55A87E))
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .offset(x: 2, y: 1)
                    }
            }
            .accessibilityLabel("Profile and roommates")
        }
        .foregroundStyle(Palette.ink)
    }
}

// MARK: - Bottom nav

enum MainTab { case fridge, recipes }

struct BottomNav: View {
    @Binding var tab: MainTab
    let onScan: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            navButton(.fridge, icon: "refrigerator", title: "Fridge")
            Button(action: onScan) {
                Image(systemName: "camera")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 70, height: 70)
                    .background(Circle().fill(Color(hex: 0xF5BD3F)))
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 3))
                    .background(Circle().fill(Palette.ink).offset(x: 3, y: 4))
            }
            .accessibilityLabel("Scan groceries")
            .offset(y: -30)
            .frame(width: 84)
            navButton(.recipes, icon: "frying.pan", title: "Recipes")
        }
        .frame(height: 76)
        .cartoonCard(fill: Color(hex: 0xFFFDF8), radius: 24, shadow: 4)
        .padding(.horizontal, 13)
    }

    private func navButton(_ target: MainTab, icon: String, title: String) -> some View {
        Button {
            tab = target
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .medium))
                Text(title).font(AppFont.rounded(11, .heavy))
            }
            .foregroundStyle(tab == target ? Palette.activeGreen : Palette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
