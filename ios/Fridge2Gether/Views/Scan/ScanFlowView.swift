import SwiftUI
import PhotosUI

/// Camera → AI finds the groceries → Review & Edit → saved to the fridge.
struct ScanFlowView: View {
    let onDone: () -> Void

    private enum Stage { case camera, analyzing, review }

    @StateObject private var camera = CameraController()
    @State private var stage: Stage = .camera
    @State private var photo: UIImage?
    @State private var items: [DetectedItem] = []
    @State private var aiNote: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var focusPoint: CGPoint?

    var body: some View {
        Group {
            switch stage {
            case .camera: cameraScreen
            case .analyzing: analyzingScreen
            case .review:
                ReviewEditView(items: $items, note: aiNote, onBack: retake, onSaved: onDone)
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    analyze(image)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: Camera

    private var cameraScreen: some View {
        ZStack {
            Color(hex: 0x142522).ignoresSafeArea()
            if camera.isAvailable {
                CameraPreview(session: camera.session) { viewPoint, devicePoint in
                    camera.focus(at: devicePoint)
                    showFocus(at: viewPoint)
                }
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(colors: [Color(hex: 0x10201F, opacity: 0.45), .clear, .clear, Color(hex: 0x10201F, opacity: 0.8)],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                        .allowsHitTesting(false) // let taps reach the preview for focusing
                )
                .overlay(alignment: .topLeading) {
                    if let focusPoint {
                        // Yellow square where you tapped, like the Camera app.
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: 0xF5BD3F), lineWidth: 1.5)
                            .frame(width: 74, height: 74)
                            .position(focusPoint)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: camera.permissionDenied ? "camera.badge.ellipsis" : "photo.on.rectangle")
                        .font(.system(size: 44))
                    Text(camera.permissionDenied ? "Camera access is off. Turn it on in Settings, or pick a photo." : "No camera here. Pick a photo of your groceries.")
                        .font(AppFont.rounded(14, .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .foregroundStyle(.white.opacity(0.85))
            }

            VStack {
                HStack {
                    RoundBackButton(dark: true) { onDone() }
                    Spacer()
                }
                Spacer()
                Label("Get all your groceries in the photo. Tap to focus.", systemImage: "sparkles")
                    .font(AppFont.rounded(14, .heavy))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding(.bottom, 28)
                HStack {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .accessibilityLabel("Choose from library")
                    Spacer()
                    Button {
                        camera.capture { image in
                            if let image { analyze(image) }
                        }
                    } label: {
                        Circle().fill(.white)
                            .padding(6)
                            .frame(width: 80, height: 80)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                    .disabled(!camera.isAvailable)
                    .opacity(camera.isAvailable ? 1 : 0.35)
                    .accessibilityLabel("Take photo")
                    Spacer()
                    Color.clear.frame(width: 50, height: 50)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: Analyzing

    private var analyzingScreen: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xEEF8F6), Color(hex: 0xF9F4E8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 170)
                        .clipShape(StickerBlob())
                        .overlay(StickerBlob().stroke(.white, lineWidth: 16).clipShape(StickerBlob()))
                        .shadow(color: Palette.ink.opacity(0.2), radius: 8, y: 6)
                        .rotationEffect(.degrees(-3))
                }
                ProgressView().tint(Palette.ink).scaleEffect(1.2)
                Label("AI is finding your groceries...", systemImage: "sparkles")
                    .font(AppFont.rounded(16, .black))
                    .foregroundStyle(Palette.ink)
                Text("Cutting each item into its own sticker")
                    .font(AppFont.rounded(13, .semibold))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    // MARK: Logic

    private func showFocus(at point: CGPoint) {
        withAnimation(.easeOut(duration: 0.15)) { focusPoint = point }
        let shown = point
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if focusPoint == shown { withAnimation(.easeOut(duration: 0.3)) { focusPoint = nil } }
        }
    }

    private func retake() {
        items = []
        photo = nil
        aiNote = nil
        stage = .camera
    }

    private func analyze(_ image: UIImage) {
        let upright = ImageProcessor.resized(image, maxSide: 1600)
        photo = upright
        stage = .analyzing
        camera.stop()
        Task {
            let today = Calendar.current.startOfDay(for: Date())
            do {
                let scanned = try await Array(DeepSeekService.scanGroceries(upright).prefix(8))
                // Cut out all stickers at the same time instead of one after another.
                let stickers: [UIImage] = await withTaskGroup(of: (Int, UIImage).self) { group in
                    for (index, item) in scanned.enumerated() {
                        let box = item.box
                        group.addTask { (index, await ImageProcessor.makeSticker(from: upright, box: box)) }
                    }
                    var output = [UIImage?](repeating: nil, count: scanned.count)
                    for await (index, image) in group { output[index] = image }
                    return output.map { $0 ?? upright }
                }
                var results: [DetectedItem] = []
                for (index, item) in scanned.enumerated() {
                    let sticker = stickers[index]
                    let days = max(item.shelfLifeDays ?? 5, 0)
                    let quantity = item.quantity.map { Food.format($0) } ?? "1"
                    results.append(DetectedItem(
                        name: item.name,
                        expiry: Calendar.current.date(byAdding: .day, value: days, to: today) ?? today,
                        quantityText: "\(quantity) \(item.unit ?? "pcs")",
                        sticker: sticker
                    ))
                }
                if results.isEmpty {
                    aiNote = "AI didn't spot any food. Add it by hand below."
                    let blank = await blankItem(from: upright, today: today)
                    items = [blank]
                } else {
                    aiNote = nil
                    items = results
                }
            } catch {
                aiNote = "AI couldn't read this photo (\(AppStore.friendly(error))). Fill it in by hand."
                let blank = await blankItem(from: upright, today: today)
                items = [blank]
            }
            stage = .review
        }
    }

    private func blankItem(from image: UIImage, today: Date) async -> DetectedItem {
        DetectedItem(
            name: "",
            expiry: Calendar.current.date(byAdding: .day, value: 5, to: today) ?? today,
            quantityText: "1 pcs",
            sticker: await ImageProcessor.makeSticker(from: image, box: nil)
        )
    }
}
