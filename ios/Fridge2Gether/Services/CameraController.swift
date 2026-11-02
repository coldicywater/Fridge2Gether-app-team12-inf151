import AVFoundation
import SwiftUI
import UIKit

/// Live camera for the scan screen. On the Simulator `isAvailable` is false and the UI offers the photo library.
final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var isAvailable = false
    @Published var permissionDenied = false

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "fridge2gether.camera")
    private var configured = false
    private var completion: ((UIImage?) -> Void)?
    private var device: AVCaptureDevice?
    private var subjectObserver: NSObjectProtocol?

    deinit {
        if let subjectObserver { NotificationCenter.default.removeObserver(subjectObserver) }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndRun() } else { self?.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard
                    let device = Self.bestBackCamera(),
                    let input = try? AVCaptureDeviceInput(device: device)
                else {
                    DispatchQueue.main.async { self.isAvailable = false }
                    return
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if self.session.canAddInput(input) { self.session.addInput(input) }
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
                self.session.commitConfiguration()
                self.device = device
                self.setUpFocus(device)
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isAvailable = true }
        }
    }

    // MARK: Focus

    /// The multi-lens camera (on phones that have one) switches to the ultra wide lens for close-ups,
    /// like the built-in Camera app's macro mode. The plain wide lens can't focus closer than ~15–20 cm.
    private static func bestBackCamera() -> AVCaptureDevice? {
        let order: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: order, mediaType: .video, position: .back)
        for type in order {
            if let device = discovery.devices.first(where: { $0.deviceType == type }) { return device }
        }
        return nil
    }

    private func setUpFocus(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.isSubjectAreaChangeMonitoringEnabled = true
            // On multi-lens cameras zoom 1.0 is the ultra wide lens. Start at the normal "1x" view
            // (the first switch-over point); the camera drops to ultra wide by itself when you get close.
            if device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera,
               let normal = device.virtualDeviceSwitchOverVideoZoomFactors.first {
                device.videoZoomFactor = CGFloat(truncating: normal)
            }
            device.unlockForConfiguration()
        } catch {}

        // After a tap-to-focus, go back to continuous focus once the scene changes.
        subjectObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: device, queue: nil
        ) { [weak self] _ in
            self?.focus(at: CGPoint(x: 0.5, y: 0.5), continuous: true)
        }
    }

    /// `point` is in device coordinates (0...1). Tap-to-focus uses a one-time focus on that spot.
    func focus(at point: CGPoint, continuous: Bool = false) {
        queue.async { [weak self] in
            guard let device = self?.device else { return }
            do {
                try device.lockForConfiguration()
                let focusMode: AVCaptureDevice.FocusMode = continuous ? .continuousAutoFocus : .autoFocus
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = point
                    device.focusMode = focusMode
                }
                let exposureMode: AVCaptureDevice.ExposureMode = continuous ? .continuousAutoExposure : .autoExpose
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = exposureMode
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    // MARK: Capture

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        guard isAvailable else {
            completion(nil)
            return
        }
        self.completion = completion
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async { [weak self] in
            self?.completion?(image)
            self?.completion = nil
        }
    }
}

/// Full-screen preview layer. Tap anywhere to focus there.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// (point in the view, point in camera coordinates 0...1)
    var onTap: (CGPoint, CGPoint) -> Void = { _, _ in }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject {
        var onTap: (CGPoint, CGPoint) -> Void
        init(onTap: @escaping (CGPoint, CGPoint) -> Void) { self.onTap = onTap }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PreviewView else { return }
            let point = gesture.location(in: view)
            onTap(point, view.previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped)))
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }
}
