import AppKit

// MARK: - File Category
enum FileCategory {
    case video
    case audio
    case image
    case document
    case generic

    static func detect(from urls: [URL]) -> FileCategory {
        guard let first = urls.first else { return .generic }
        let ext = first.pathExtension.lowercased()

        switch ext {
        case "avi", "mp4", "mov", "mkv", "webm", "flv", "wmv", "m4v", "ts", "3gp", "vob":
            return .video
        case "wav", "mp3", "m4a", "flac", "ogg", "opus", "aiff", "aac", "wma", "alac":
            return .audio
        case "png", "jpg", "jpeg", "heic", "webp", "gif", "tiff", "bmp", "svg", "raw", "cr2", "nef":
            return .image
        case "pdf", "txt", "rtf", "doc", "docx", "pages":
            return .document
        default:
            return .video // Default to video/general if unknown
        }
    }
}

// MARK: - Wheel Segment
struct WheelSegment: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let action: SegmentAction

    // MARK: - Dynamic Segment Sets
    static func segments(for mode: WheelMode, category: FileCategory = .video) -> [WheelSegment] {
        if mode == .tools {
            return toolSegments
        }

        switch category {
        case .video:
            return videoSegments
        case .audio:
            return audioSegments
        case .image:
            return imageSegments
        case .document, .generic:
            return genericSegments
        }
    }

    // Video Wheel (6 sectors)
    static let videoSegments: [WheelSegment] = [
        WheelSegment(label: "MP4",  icon: "film",           action: .convert(.mp4)),
        WheelSegment(label: "MOV",  icon: "play.tv",        action: .convert(.mov)),
        WheelSegment(label: "MKV",  icon: "video.fill",     action: .convert(.mkv)),
        WheelSegment(label: "WEBM", icon: "globe",          action: .convert(.webm)),
        WheelSegment(label: "GIF",  icon: "play.rectangle", action: .convert(.gif)),
        WheelSegment(label: "MP3",  icon: "music.note",     action: .convert(.mp3)),
    ]

    // Audio Wheel (6 sectors - exact match with user photo)
    static let audioSegments: [WheelSegment] = [
        WheelSegment(label: "MP3",  icon: "music.note",        action: .convert(.mp3)),
        WheelSegment(label: "M4A",  icon: "waveform",          action: .convert(.m4a)),
        WheelSegment(label: "FLAC", icon: "hifispeaker",       action: .convert(.flac)),
        WheelSegment(label: "OGG",  icon: "speaker.wave.2",    action: .convert(.ogg)),
        WheelSegment(label: "OPUS", icon: "mic",               action: .convert(.opus)),
        WheelSegment(label: "AIFF", icon: "waveform.path.ecg", action: .convert(.aiff)),
    ]

    // Image Wheel (6 sectors)
    static let imageSegments: [WheelSegment] = [
        WheelSegment(label: "PNG",  icon: "photo.fill",   action: .convert(.png)),
        WheelSegment(label: "JPEG", icon: "photo",        action: .convert(.jpeg)),
        WheelSegment(label: "WEBP", icon: "globe",        action: .convert(.webp)),
        WheelSegment(label: "HEIC", icon: "applelogo",    action: .convert(.heic)),
        WheelSegment(label: "PDF",  icon: "doc.richtext", action: .convert(.pdf)),
        WheelSegment(label: "GIF",  icon: "sparkles",     action: .convert(.gif)),
    ]

    // Generic / Document Wheel
    static let genericSegments: [WheelSegment] = [
        WheelSegment(label: "PDF",  icon: "doc.fill",  action: .convert(.pdf)),
        WheelSegment(label: "ZIP",  icon: "archivebox", action: .compress),
        WheelSegment(label: "PNG",  icon: "photo",      action: .convert(.png)),
        WheelSegment(label: "MP4",  icon: "film",       action: .convert(.mp4)),
        WheelSegment(label: "MP3",  icon: "music.note", action: .convert(.mp3)),
        WheelSegment(label: "TXT",  icon: "doc.text",   action: .convert(.txt)),
    ]

    // Tools Wheel (Option + Shift)
    static let toolSegments: [WheelSegment] = [
        WheelSegment(label: "ZIP",        icon: "archivebox",                  action: .compress),
        WheelSegment(label: "No Meta",    icon: "eye.slash",                   action: .stripMetadata),
        WheelSegment(label: "Resize 50%", icon: "arrow.up.left.and.arrow.down.right", action: .resize),
        WheelSegment(label: "QR Read",    icon: "qrcode",                      action: .readQR),
        WheelSegment(label: "Trim",       icon: "scissors",                    action: .trim),
        WheelSegment(label: "Compress",   icon: "rectangle.compress.vertical", action: .compress),
    ]
}

// MARK: - Segment Action
enum SegmentAction {
    case convert(TargetFormat)
    case compress
    case stripMetadata
    case resize
    case trim
    case readQR
}

// MARK: - Target Format
enum TargetFormat: String, CaseIterable {
    case mp4, mov, mkv, webm
    case mp3, m4a, wav, flac, ogg, opus, aiff
    case jpeg, png, webp, heic, gif
    case pdf, txt
}
