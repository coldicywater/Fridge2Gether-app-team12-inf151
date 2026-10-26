import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Palette from the Week 3 concept art and the Figma Make CSS.
enum Palette {
    static let ink = Color(hex: 0x243938)          // text + outlines
    static let cream = Color(hex: 0xF8F4EA)        // app background
    static let card = Color(hex: 0xFFFDF8)         // cards, sheets
    static let fridgeBlue = Color(hex: 0xB9E1EB)
    static let shelfWhite = Color(hex: 0xF9FDFF)
    static let sharedGreen = Color(hex: 0xEDF8F2)
    static let sharedText = Color(hex: 0x2E7B5D)
    static let expiringYellow = Color(hex: 0xFFF8DC)
    static let expiringBorder = Color(hex: 0x716238)
    static let expiringInset = Color(hex: 0xF4D980)
    static let expiringText = Color(hex: 0xA05E2F)
    static let yellow = Color(hex: 0xF4BB3F)       // primary buttons
    static let soonYellow = Color(hex: 0xF7CA56)
    static let coral = Color(hex: 0xEF6F61)
    static let green = Color(hex: 0x3F8E71)
    static let activeGreen = Color(hex: 0x288263)
    static let mint = Color(hex: 0xD9EFE4)
    static let muted = Color(hex: 0x71817C)
    static let eyebrow = Color(hex: 0x60817B)
    static let avatar = Color(hex: 0xF4AB76)
    static let roommate = Color(hex: 0xE6B094)
    static let leg = Color(hex: 0xF6A66B)
    static let lightBorder = Color(hex: 0xC4CBC7)
    static let danger = Color(hex: 0xB64940)
}

enum AppFont {
    /// Nunito in the prototype; SF Rounded is the native look-alike.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Hand-drawn labels ("Personal", "Shared", "fresh stuff").
    static func hand(_ size: CGFloat) -> Font {
        if UIFont(name: "PatrickHand-Regular", size: size) != nil {
            return .custom("PatrickHand-Regular", size: size)
        }
        return .custom("ChalkboardSE-Regular", size: size)
    }
}

// MARK: - Reusable styles

/// Chunky yellow button with offset shadow.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Palette.yellow
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.rounded(14, .black))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.ink, lineWidth: 2))
            .background(
                RoundedRectangle(cornerRadius: 14).fill(Palette.ink)
                    .offset(x: configuration.isPressed || !isEnabled ? 0 : 2,
                            y: configuration.isPressed || !isEnabled ? 0 : 3)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// White outlined button.
struct SecondaryButtonStyle: ButtonStyle {
    var fill: Color = .white
    var textColor: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.rounded(13, .black))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.ink, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Small pill in a segmented picker (Just Me / Everyone / Selected Roommates).
struct ChipButtonStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.rounded(11, .black))
            .foregroundStyle(selected ? .white : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Palette.green : .white))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? Palette.ink : Color(hex: 0xB5C0BB), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    /// Outlined card with the cartoon offset shadow.
    func cartoonCard(fill: Color = Palette.card, radius: CGFloat = 17, shadow: CGFloat = 3) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Palette.ink, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: radius).fill(Palette.ink).offset(x: shadow, y: shadow + 1))
    }

    func eyebrowStyle() -> some View {
        self.font(AppFont.rounded(11, .black))
            .tracking(1.8)
            .foregroundStyle(Palette.eyebrow)
    }

    func fieldStyle() -> some View {
        self
            .font(AppFont.rounded(15, .heavy))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 13)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color(hex: 0xFFFDF9)))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.ink, lineWidth: 2))
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.rounded(11, .black))
            .tracking(0.8)
            .foregroundStyle(Color(hex: 0x637873))
            .padding(.leading, 3)
    }
}

/// Soft cream gradient used behind most screens.
struct ScreenBackground: View {
    var top: Color = Color(hex: 0xFDFBF5)
    var bottom: Color = Color(hex: 0xF4F1E8)
    var body: some View {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct RoundBackButton: View {
    var dark = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(dark ? .white : Palette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(dark ? Color.black.opacity(0.35) : Palette.card))
                .overlay(Circle().stroke(dark ? Color.white.opacity(0.5) : Palette.ink, lineWidth: 2))
        }
        .accessibilityLabel("Back")
    }
}
