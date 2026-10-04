import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

struct PreparedImage {
    let png: Data
    let fingerprint: ImageFingerprint
}

struct ImageProcessor {
    func fingerprint(_ image: CGImage) throws -> ImageFingerprint {
        let width = 128, height = 96
        var pixels = [UInt8](repeating: 0, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { throw LensError.imageProcessing }
        return ImageFingerprint(pixels: pixels)
    }

    func prepare(_ image: CGImage) throws -> PreparedImage {
        let fingerprint = try fingerprint(image)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw LensError.imageProcessing }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw LensError.imageProcessing }
        return PreparedImage(png: data as Data, fingerprint: fingerprint)
    }
}
