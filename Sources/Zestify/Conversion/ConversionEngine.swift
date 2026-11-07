import Foundation
import AppKit
import UniformTypeIdentifiers
import ImageIO
import CoreImage
import CoreServices
import AVFoundation

// MARK: - Conversion Engine
final class ConversionEngine {

    static let shared = ConversionEngine()
    private init() {}

    // MARK: - Locate FFmpeg Helper
    static func locateFFmpeg() -> String? {
        var candidates: [String] = []
        if let path = Bundle.main.resourceURL?.appendingPathComponent("ffmpeg").path {
            candidates.append(path)
        }
        candidates.append("/Applications/Zestify.app/Contents/Resources/ffmpeg")
        candidates.append("/Users/tddan/.gemini/antigravity/scratch/Zestify/Resources/ffmpeg")
        candidates.append("/tmp/ffmpeg")
        candidates.append("/opt/homebrew/bin/ffmpeg")
        candidates.append("/usr/local/bin/ffmpeg")

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

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
                self.resizeFiles(urls, scale: 0.5, completion: completion)
            case .trim:
                completion(.partial(converted: 0, failed: urls.count, message: "Обрезка видео доступна в полной версии"))
            case .readQR:
                self.readQRCodes(from: urls, completion: completion)
            }
        }
    }

    // MARK: - File Conversion
    private func convertFiles(_ urls: [URL], to format: TargetFormat, completion: @escaping (ConversionResult) -> Void) {
        var createdUrls: [URL] = []
        var failed = 0

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let ext = formatExtension(for: format)
            let outputURL = outputPath(for: url, extension: ext)

            var success = false

            switch format {
            case .mp4, .mov, .mkv, .webm, .gif, .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff:
                success = convertMedia(input: url, output: outputURL, format: format)
            case .jpeg, .png, .webp, .heic:
                success = convertImage(input: url, output: outputURL, format: format)
            case .pdf:
                success = imageToPDF(input: url, output: outputURL)
            case .txt:
                success = extractText(input: url, output: outputURL)
            }

            if success && FileManager.default.fileExists(atPath: outputURL.path) {
                createdUrls.append(outputURL)
            } else {
                failed += 1
            }
        }

        if failed == 0 && !createdUrls.isEmpty {
            completion(.success(outputUrls: createdUrls))
        } else if !createdUrls.isEmpty {
            completion(.partial(converted: createdUrls.count, failed: failed, message: nil))
        } else {
            completion(.failure(error: "Не удалось сконвертировать файл(ы)"))
        }
    }

    // MARK: - Video & Audio Conversion (FFmpeg with AVFoundation Fallback)
    private func convertMedia(input: URL, output: URL, format: TargetFormat) -> Bool {
        if let ffmpeg = ConversionEngine.locateFFmpeg() {
            var args = ["-i", input.path]

            switch format {
            case .mp4:
                args += ["-c:v", "libx264", "-preset", "fast", "-crf", "22", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
            case .mov:
                args += ["-c:v", "libx264", "-preset", "fast", "-c:a", "aac", "-movflags", "+faststart"]
            case .mkv:
                args += ["-c:v", "libx264", "-preset", "fast", "-c:a", "aac"]
            case .webm:
                args += ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "30", "-c:a", "libopus"]
            case .gif:
                args += ["-vf", "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"]
            case .mp3:
                args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
            case .m4a:
                args += ["-vn", "-c:a", "aac", "-b:a", "256k"]
            case .wav:
                args += ["-vn", "-c:a", "pcm_s16le"]
            case .flac:
                args += ["-vn", "-c:a", "flac"]
            case .ogg:
                args += ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
            case .opus:
                args += ["-vn", "-c:a", "libopus", "-b:a", "128k"]
            case .aiff:
                args += ["-vn", "-c:a", "pcm_s16be"]
            default:
                break
            }

            args += [output.path, "-y"]

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ffmpeg)
            proc.arguments = args

            do {
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: output.path)
            } catch {
                // Try AVFoundation fallback below
            }
        }

        // AVFoundation Fallback
        return convertWithAVFoundation(input: input, output: output, format: format)
    }

    private func convertWithAVFoundation(input: URL, output: URL, format: TargetFormat) -> Bool {
        let asset = AVURLAsset(url: input)
        let preset: String
        let fileType: AVFileType

        switch format {
        case .mp4:
            preset = AVAssetExportPresetHighestQuality
            fileType = .mp4
        case .mov:
            preset = AVAssetExportPresetHighestQuality
            fileType = .mov
        case .m4a, .mp3, .wav, .aiff:
            preset = AVAssetExportPresetAppleM4A
            fileType = .m4a
        default:
            return false
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { return false }
        session.outputURL = output
        session.outputFileType = fileType

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        session.exportAsynchronously {
            success = (session.status == .completed)
            semaphore.signal()
        }
        semaphore.wait()
        return success
    }

    // MARK: - Image Conversion (sips & ImageIO)
    private func convertImage(input: URL, output: URL, format: TargetFormat) -> Bool {
        let sipsFormat: String?
        switch format {
        case .jpeg: sipsFormat = "jpeg"
        case .png:  sipsFormat = "png"
        case .heic: sipsFormat = "heic"
        case .gif:  sipsFormat = "gif"
        default:    sipsFormat = nil
        }

        if let sipsFmt = sipsFormat {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
            proc.arguments = ["-s", "format", sipsFmt, input.path, "--out", output.path]
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: output.path) {
                    return true
                }
            } catch {}
        }

        // WebP or Fallback with CoreImage / ImageIO
        guard let ciImage = CIImage(contentsOf: input) else { return false }
        let uti = format == .webp ? "org.webmproject.webp" : UTType.png.identifier
        guard let dest = CGImageDestinationCreateWithURL(output as CFURL, uti as CFString, 1, nil) else { return false }
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return false }
        CGImageDestinationAddImage(dest, cgImage, nil)
        return CGImageDestinationFinalize(dest)
    }

    // MARK: - Image to PDF
    private func imageToPDF(input: URL, output: URL) -> Bool {
        guard let image = NSImage(contentsOf: input) else { return false }
        let pdfDoc = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfDoc as CFMutableData) else { return false }
        var mediaBox = CGRect(origin: .zero, size: image.size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return false }
        context.beginPDFPage(nil)
        var rect = NSRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            context.draw(cgImage, in: mediaBox)
        }
        context.endPDFPage()
        context.closePDF()
        return (try? pdfDoc.write(to: output, options: .atomic)) != nil
    }

    // MARK: - Text Extraction
    private func extractText(input: URL, output: URL) -> Bool {
        if let str = try? String(contentsOf: input) {
            return (try? str.write(to: output, atomically: true, encoding: .utf8)) != nil
        }
        return false
    }

    // MARK: - Compress to ZIP
    private func compressFiles(_ urls: [URL], completion: @escaping (ConversionResult) -> Void) {
        let dir = urls.first?.deletingLastPathComponent() ?? Preferences.shared.customSaveDirectory
        let baseName = urls.count == 1 ? urls[0].deletingPathExtension().lastPathComponent : "Archive"
        var zipURL = dir.appendingPathComponent("\(baseName).zip")
        var counter = 1
        while FileManager.default.fileExists(atPath: zipURL.path) {
            zipURL = dir.appendingPathComponent("\(baseName) (\(counter)).zip")
            counter += 1
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        proc.arguments = ["-j", zipURL.path] + urls.map(\.path)

        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: zipURL.path) {
                completion(.success(outputUrls: [zipURL]))
            } else {
                completion(.failure(error: "Не удалось создать архив"))
            }
        } catch {
            completion(.failure(error: error.localizedDescription))
        }
    }

    // MARK: - Strip Metadata
    private func stripMetadataFromFiles(_ urls: [URL], completion: @escaping (ConversionResult) -> Void) {
        var cleanUrls: [URL] = []
        for url in urls {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let uti = CGImageSourceGetType(source) else { continue }

            let outURL = outputPath(for: url, extension: url.pathExtension)
            guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, uti, CGImageSourceGetCount(source), nil) else { continue }

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
            if CGImageDestinationFinalize(dest) {
                cleanUrls.append(outURL)
            }
        }

        if !cleanUrls.isEmpty {
            completion(.success(outputUrls: cleanUrls))
        } else {
            completion(.failure(error: "Не удалось удалить метаданные"))
        }
    }

    // MARK: - Resize (50%)
    private func resizeFiles(_ urls: [URL], scale: CGFloat, completion: @escaping (ConversionResult) -> Void) {
        var resizedUrls: [URL] = []
        for url in urls {
            guard let image = NSImage(contentsOf: url) else { continue }
            let newSize = NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            newImage.unlockFocus()

            let outURL = outputPath(for: url, extension: url.pathExtension)
            if let tiff = newImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
                if (try? jpeg.write(to: outURL)) != nil {
                    resizedUrls.append(outURL)
                }
            }
        }

        if !resizedUrls.isEmpty {
            completion(.success(outputUrls: resizedUrls))
        } else {
            completion(.failure(error: "Не удалось изменить размер"))
        }
    }

    // MARK: - QR Code Reader
    private func readQRCodes(from urls: [URL], completion: @escaping (ConversionResult) -> Void) {
        var results: [String] = []
        for url in urls {
            guard let ciImage = CIImage(contentsOf: url) else { continue }
            let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] ?? []
            results.append(contentsOf: features.compactMap(\.messageString))
        }

        DispatchQueue.main.async {
            if results.isEmpty {
                completion(.failure(error: "QR-код не обнаружен"))
            } else {
                let combined = results.joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(combined, forType: .string)
                completion(.success(outputUrls: []))
            }
        }
    }

    // MARK: - Helpers (Output directly in the same folder!)
    private func outputPath(for url: URL, extension ext: String) -> URL {
        let dir: URL
        if Preferences.shared.saveNextToOriginal {
            dir = url.deletingLastPathComponent()
        } else {
            dir = Preferences.shared.customSaveDirectory
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        let targetExt = ext.lowercased()
        let sourceExt = url.pathExtension.lowercased()

        if targetExt != sourceExt {
            var candidate = dir.appendingPathComponent(baseName).appendingPathExtension(targetExt)
            var counter = 1
            while FileManager.default.fileExists(atPath: candidate.path) {
                candidate = dir.appendingPathComponent("\(baseName) (\(counter))").appendingPathExtension(targetExt)
                counter += 1
            }
            return candidate
        } else {
            var candidate = dir.appendingPathComponent("\(baseName)_converted").appendingPathExtension(targetExt)
            var counter = 1
            while FileManager.default.fileExists(atPath: candidate.path) {
                candidate = dir.appendingPathComponent("\(baseName)_converted_\(counter)").appendingPathExtension(targetExt)
                counter += 1
            }
            return candidate
        }
    }

    private func formatExtension(for format: TargetFormat) -> String {
        switch format {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .mkv: return "mkv"
        case .webm: return "webm"
        case .gif: return "gif"
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        case .wav: return "wav"
        case .flac: return "flac"
        case .ogg: return "ogg"
        case .opus: return "opus"
        case .aiff: return "aiff"
        case .jpeg: return "jpg"
        case .png: return "png"
        case .webp: return "webp"
        case .heic: return "heic"
        case .pdf: return "pdf"
        case .txt: return "txt"
        }
    }
}
