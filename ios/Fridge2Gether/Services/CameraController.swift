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
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.isAvailable = true }
        }
    }

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

/// Full-screen preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
