import UIKit
import Vision
import CoreImage

/// Turns a grocery photo into one round "sticker" per item:
/// crop to the AI's bounding box, then lift the subject off its background (Apple Vision).
enum ImageProcessor {
    private static let ciContext = CIContext()

    /// Redraws the image upright and no larger than `maxSide`.
    static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Crops to a normalized [x, y, w, h] box with a little padding. Falls back to a centered square.
    static func crop(_ image: UIImage, box: [Double]?) -> UIImage {
        let upright = resized(image, maxSide: 1600)
        guard let cg = upright.cgImage else { return upright }
        let width = CGFloat(cg.width), height = CGFloat(cg.height)

        var rect: CGRect
        if let box, box.count == 4, box[2] > 0.02, box[3] > 0.02 {
            rect = CGRect(x: box[0] * width, y: box[1] * height, width: box[2] * width, height: box[3] * height)
            rect = rect.insetBy(dx: -rect.width * 0.12, dy: -rect.height * 0.12)
        } else {
            let side = min(width, height) * 0.8
            rect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
        }
        rect = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height)).integral
        guard rect.width > 10, rect.height > 10, let cropped = cg.cropping(to: rect) else { return upright }
        return UIImage(cgImage: cropped)
    }

    /// Background removal with Vision's subject lifting (iOS 17+, real devices).
    /// Returns nil on the Simulator or when no subject is found.
    static func liftSubject(_ image: UIImage) async -> UIImage? {
        guard let cg = resized(image, maxSide: 800).cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
                guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
                let buffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: true
                )
                let ci = CIImage(cvPixelBuffer: buffer)
                guard let output = ImageProcessor.ciContext.createCGImage(ci, from: ci.extent) else { return nil }
                return UIImage(cgImage: output)
            } catch {
                return nil
            }
        }.value
    }

    /// Crop + lift for one detected item.
    static func makeSticker(from photo: UIImage, box: [Double]?) async -> UIImage {
        let cropped = crop(photo, box: box)
        if let lifted = await liftSubject(cropped) {
            return onWhite(lifted)
        }
        return cropped
    }

    /// Centers a transparent cutout on a white square so it reads like a sticker.
    static func onWhite(_ cutout: UIImage) -> UIImage {
        let side = max(cutout.size.width, cutout.size.height) * 1.15
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            cutout.draw(in: CGRect(
                x: (side - cutout.size.width) / 2,
                y: (side - cutout.size.height) / 2,
                width: cutout.size.width,
                height: cutout.size.height
            ))
        }
    }

    /// Small JPEG for Firestore (each document must stay under 1 MB).
    static func stickerBase64(_ image: UIImage) -> String? {
        let small = resized(image, maxSide: 320)
        return small.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}
