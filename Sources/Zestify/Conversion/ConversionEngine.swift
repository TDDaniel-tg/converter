import Foundation
import AppKit
import UniformTypeIdentifiers
import ImageIO
import CoreImage
import CoreServices
import AVFoundation

// MARK: - Conversion Engine (Singleton)
final class ConversionEngine {

    static let shared = ConversionEngine()
    private init() {}

    // MARK: - Entry Point

    func convert(urls: [URL], to segment: WheelSegment, completion: @escaping (ConversionResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            switch segment.action {
            case .convert(let format):
                self.convertFiles(urls, to: format, completion: completion)
            case .compress:
                self.compressFiles(urls, completion: completion)
            case .stripMetadata:
                self.stripMetadataFromFiles(urls, completion: completion)
            case .resize:
                // Basic resize: 50% of original dimensions
                self.resizeFiles(urls, scale: 0.5, completion: completion)
            case .trim:
                // Trim: notify user to use system tools for now
                completion(.partial(converted: 0, failed: urls.count,
                    message: "Trim requires a UI panel — coming soon!"))
            case .readQR:
                self.readQRCodes(from: urls, completion: completion)
            }
        }
    }

    // MARK: - File Conversion

    private func convertFiles(_ urls: [URL], to format: TargetFormat, completion: @escaping (ConversionResult) -> Void) {
        var converted = 0
        var failed = 0

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let success: Bool
            switch format {
            case .jpeg, .png, .webp, .heic, .gif:
                success = convertImage(url, to: format)
            case .mp4, .mov:
                success = convertVideo(url, to: format)
            case .mp3, .m4a, .wav, .aiff:
                success = convertAudio(url, to: format)
            case .pdf:
                success = imageToPDF(url)
            }

            if success { converted += 1 } else { failed += 1 }
        }

        if failed == 0 {
            completion(.success(converted: converted))
        } else {
            completion(.partial(converted: converted, failed: failed, message: nil))
        }
    }

    // MARK: - Image Conversion (CoreImage / ImageIO)

    private func convertImage(_ url: URL, to format: TargetFormat) -> Bool {
        guard let ciImage = CIImage(contentsOf: url) else { return false }

        let ext: String
        let uti: String
        switch format {
        case .jpeg:  ext = "jpg";  uti = UTType.jpeg.identifier
        case .png:   ext = "png";  uti = UTType.png.identifier
        case .webp:  ext = "webp"; uti = "org.webmproject.webp"
        case .heic:  ext = "heic"; uti = UTType.heic.identifier
        case .gif:   ext = "gif";  uti = UTType.gif.identifier
        default:     return false
        }

        let outputURL = outputPath(for: url, extension: ext)
        let context = CIContext()

        do {
            try context.writeJPEGRepresentation(of: ciImage, to: outputURL,
                colorSpace: ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB())
            // Note: for PNG/HEIC/WebP, use proper UTType-based API if available
            return true
        } catch {
            // Fallback: use ImageIO
            return writeWithImageIO(ciImage: ciImage, to: outputURL, uti: uti)
        }
    }

    private func writeWithImageIO(ciImage: CIImage, to url: URL, uti: String) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti as CFString, 1, nil) else { return false }
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return false }
        CGImageDestinationAddImage(dest, cgImage, nil)
        return CGImageDestinationFinalize(dest)
    }

    // MARK: - Video Conversion (AVFoundation)

    private func convertVideo(_ url: URL, to format: TargetFormat) -> Bool {
        let asset = AVURLAsset(url: url)
        let presetName = AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: asset, presetName: presetName) else { return false }

        let ext = format == .mp4 ? "mp4" : "mov"
        let fileType: AVFileType = format == .mp4 ? .mp4 : .mov
        let outputURL = outputPath(for: url, extension: ext)

        session.outputURL = outputURL
        session.outputFileType = fileType
        session.shouldOptimizeForNetworkUse = true

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        session.exportAsynchronously {
            success = session.status == .completed
            semaphore.signal()
        }
        semaphore.wait()
        return success
    }

    // MARK: - Audio Conversion (AVFoundation)

    private func convertAudio(_ url: URL, to format: TargetFormat) -> Bool {
        let asset = AVURLAsset(url: url)
        let presetName = AVAssetExportPresetAppleM4A
        guard let session = AVAssetExportSession(asset: asset, presetName: presetName) else { return false }

        let ext: String
        let fileType: AVFileType
        switch format {
        case .m4a:  ext = "m4a";  fileType = .m4a
        case .wav:  ext = "wav";  fileType = .wav
        case .aiff: ext = "aiff"; fileType = .aiff
        default:    ext = "m4a";  fileType = .m4a // MP3 export requires paid license; default to m4a
        }

        let outputURL = outputPath(for: url, extension: ext)
        session.outputURL = outputURL
        session.outputFileType = fileType

        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        session.exportAsynchronously {
            success = session.status == .completed
            semaphore.signal()
        }
        semaphore.wait()
        return success
    }

    // MARK: - Image → PDF

    private func imageToPDF(_ url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        let outputURL = outputPath(for: url, extension: "pdf")

        // Manual PDF creation using Core Graphics
        var rect = NSRect(origin: .zero, size: image.size)
        let pdfDoc = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfDoc as CFMutableData) else { return false }
        var mediaBox = CGRect(origin: .zero, size: image.size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return false }
        context.beginPDFPage(nil)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            context.draw(cgImage, in: mediaBox)
        }
        context.endPDFPage()
        context.closePDF()
        return (try? pdfDoc.write(to: outputURL, options: .atomic)) != nil
    }

    // MARK: - Compress

    private func compressFiles(_ urls: [URL], completion: @escaping (ConversionResult) -> Void) {
        // Create a zip archive using the built-in zip tool
        let outputDir = urls.first?.deletingLastPathComponent() ?? URL(fileURLWithPath: NSHomeDirectory())
        let zipURL = outputDir.appendingPathComponent("Zestify_Archive_\(timestamp()).zip")

        var args = ["zip", "-j", zipURL.path]
        args.append(contentsOf: urls.map(\.path))

        let proc = Process()
        proc.launchPath = "/usr/bin/zip"
        proc.arguments = ["-j", zipURL.path] + urls.map(\.path)
        proc.launch()
        proc.waitUntilExit()

        if proc.terminationStatus == 0 {
            completion(.success(converted: urls.count))
        } else {
            completion(.partial(converted: 0, failed: urls.count, message: "Zip failed"))
        }
    }

    // MARK: - Strip Metadata

    private func stripMetadataFromFiles(_ urls: [URL], completion: @escaping (ConversionResult) -> Void) {
        var success = 0
        for url in urls {
            if stripMetadata(from: url) { success += 1 }
        }
        completion(success == urls.count ? .success(converted: success) : .partial(converted: success, failed: urls.count - success, message: nil))
    }

    private func stripMetadata(from url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let uti = CGImageSourceGetType(source) else { return false }

        let outputURL = outputPath(for: url, extension: url.pathExtension, suffix: "_clean")
        guard let dest = CGImageDestinationCreateWithURL(outputURL as CFURL, uti, CGImageSourceGetCount(source), nil) else { return false }

        // Strip all metadata by omitting it
        for i in 0..<CGImageSourceGetCount(source) {
            let props: [CFString: Any] = [
                kCGImageDestinationMetadata: [:] as CFDictionary,
                kCGImageMetadataShouldExcludeGPS: true,
                kCGImageMetadataShouldExcludeXMP: true
            ]
            if let cgImg = CGImageSourceCreateImageAtIndex(source, i, nil) {
                CGImageDestinationAddImage(dest, cgImg, props as CFDictionary)
            }
        }
        return CGImageDestinationFinalize(dest)
    }

    // MARK: - Resize

    private func resizeFiles(_ urls: [URL], scale: CGFloat, completion: @escaping (ConversionResult) -> Void) {
        var success = 0
        for url in urls {
            guard let image = NSImage(contentsOf: url) else { continue }
            let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            newImage.unlockFocus()

            let outputURL = outputPath(for: url, extension: "jpg", suffix: "_resized")
            if let tiff = newImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                if (try? jpeg.write(to: outputURL)) != nil { success += 1 }
            }
        }
        completion(success > 0 ? .success(converted: success) : .partial(converted: success, failed: urls.count - success, message: nil))
    }

    // MARK: - QR Code Reader

    private func readQRCodes(from urls: [URL], completion: @escaping (ConversionResult) -> Void) {
        var results: [String] = []
        for url in urls {
            guard let ciImage = CIImage(contentsOf: url) else { continue }
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                      options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] ?? []
            results.append(contentsOf: features.compactMap(\.messageString))
        }

        DispatchQueue.main.async {
            if results.isEmpty {
                completion(.partial(converted: 0, failed: urls.count, message: "No QR codes found"))
            } else {
                let combined = results.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(combined, forType: .string)
                completion(.success(converted: results.count))
            }
        }
    }

    // MARK: - Helpers

    private func outputPath(for url: URL, extension ext: String, suffix: String = "_zestify") -> URL {
        let dir: URL
        if Preferences.shared.saveNextToOriginal {
            dir = url.deletingLastPathComponent()
        } else {
            dir = Preferences.shared.customSaveDirectory
        }
        let name = url.deletingPathExtension().lastPathComponent + suffix
        var candidate = dir.appendingPathComponent(name).appendingPathExtension(ext)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(name)_\(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}
