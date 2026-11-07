import AppKit

// MARK: - Wheel Segment
struct WheelSegment: Identifiable {
    let id = UUID()
    let label: String
    let icon: String          // SF Symbol name
    let nsColor: NSColor
    let hoverNSColor: NSColor
    let action: SegmentAction

    // MARK: - Segment Sets

    static func segments(for mode: WheelMode) -> [WheelSegment] {
        switch mode {
        case .formats: return formatSegments
        case .tools:   return toolSegments
        }
    }

    // Format Wheel — 8 segments
    static let formatSegments: [WheelSegment] = [
        WheelSegment(label: "JPEG",  icon: "photo",             nsColor: .hex("#E8724A"), hoverNSColor: .hex("#FF8C66"), action: .convert(.jpeg)),
        WheelSegment(label: "PNG",   icon: "photo.fill",        nsColor: .hex("#4A90D9"), hoverNSColor: .hex("#5AACE8"), action: .convert(.png)),
        WheelSegment(label: "WebP",  icon: "globe",             nsColor: .hex("#5DBE7E"), hoverNSColor: .hex("#70D994"), action: .convert(.webp)),
        WheelSegment(label: "HEIC",  icon: "applelogo",         nsColor: .hex("#9B6CF0"), hoverNSColor: .hex("#B589FF"), action: .convert(.heic)),
        WheelSegment(label: "MP4",   icon: "film",              nsColor: .hex("#E8974A"), hoverNSColor: .hex("#FFB36A"), action: .convert(.mp4)),
        WheelSegment(label: "MP3",   icon: "music.note",        nsColor: .hex("#E84A6E"), hoverNSColor: .hex("#FF6080"), action: .convert(.mp3)),
        WheelSegment(label: "PDF",   icon: "doc.richtext",      nsColor: .hex("#C0392B"), hoverNSColor: .hex("#E74C3C"), action: .convert(.pdf)),
        WheelSegment(label: "GIF",   icon: "play.rectangle",    nsColor: .hex("#F39C12"), hoverNSColor: .hex("#F5B839"), action: .convert(.gif)),
    ]

    // Tools Wheel — 6 segments
    static let toolSegments: [WheelSegment] = [
        WheelSegment(label: "Compress",   icon: "rectangle.compress.vertical",           nsColor: .hex("#2C7BE5"), hoverNSColor: .hex("#4293FF"), action: .compress),
        WheelSegment(label: "No Meta",    icon: "eye.slash",                             nsColor: .hex("#6C757D"), hoverNSColor: .hex("#8E9EAA"), action: .stripMetadata),
        WheelSegment(label: "ZIP",        icon: "archivebox",                            nsColor: .hex("#17A589"), hoverNSColor: .hex("#1ABC9C"), action: .compress),
        WheelSegment(label: "Resize 50%", icon: "arrow.up.left.and.arrow.down.right",    nsColor: .hex("#8E44AD"), hoverNSColor: .hex("#A65BBD"), action: .resize),
        WheelSegment(label: "Trim",       icon: "scissors",                              nsColor: .hex("#D35400"), hoverNSColor: .hex("#E67E22"), action: .trim),
        WheelSegment(label: "QR Read",    icon: "qrcode",                                nsColor: .hex("#1E8449"), hoverNSColor: .hex("#27AE60"), action: .readQR),
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
    case jpeg, png, webp, heic
    case mp4, mov, gif
    case mp3, m4a, wav, aiff
    case pdf
}

// MARK: - NSColor from Hex
extension NSColor {
    static func hex(_ hex: String) -> NSColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat(int         & 0xFF) / 255
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
