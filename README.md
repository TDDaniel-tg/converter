# Zestify 🍋

> A fast, local-first macOS file converter that lives in your menu bar.
> Convert files in a flash using drag-and-drop + modifier keys — no cloud, no subscriptions.

---

## ✨ Features

| Feature | Detail |
|---|---|
| **Format Wheel** | `Shift` + drag any file → radial format picker |
| **Tools Wheel** | `Option+Shift` + drag → compress, resize, strip metadata, QR scan |
| **Batch Processing** | Select multiple files and drag them all at once |
| **100% Local** | No internet, no uploads, no analytics |
| **Menu Bar Resident** | Stays out of the way until you need it |
| **False Positive Protection** | 300ms debounce + drag-pasteboard check before showing wheel |

## 🗂 Supported Formats

**Images:** JPEG · PNG · WebP · HEIC · GIF  
**Video:** MP4 · MOV  
**Audio:** M4A · WAV · AIFF  
**Documents:** PDF  

## 🔧 Tools
- **Compress** → ZIP archive of selected files
- **Strip Metadata** → Remove EXIF/GPS data from images  
- **Resize** → 50% scale (configurable in source)  
- **QR Reader** → Reads QR codes and copies to clipboard  

## 🚀 Getting Started

### Requirements
- macOS 13.0+ (Ventura or later)
- Apple Silicon or Intel Mac
- Xcode 15+

### Build & Run

```bash
git clone https://github.com/YOUR_USERNAME/Zestify.git
cd Zestify
open Package.swift   # Opens in Xcode
```

Or from the command line:
```bash
swift build
swift run
```

### How to Use

1. Launch Zestify — it appears as 🔶 in your menu bar
2. Select one or more files in Finder
3. Start dragging them, then hold:
   - **`Shift`** → Format Wheel (convert to JPEG, PNG, MP4, etc.)
   - **`Option + Shift`** → Tools Wheel (compress, resize, strip metadata…)
4. Drop onto a segment — Zestify converts and saves the result next to the original

## 📁 Project Structure

```
Zestify/
├── Package.swift
├── Sources/Zestify/
│   ├── App/            AppDelegate, main entry
│   ├── EventMonitor/   Global drag + modifier key detection
│   ├── RadialWheel/    Animated pie-menu UI (SwiftUI)
│   ├── Conversion/     AVFoundation, CoreImage, PDFKit engines
│   ├── Models/         WheelSegment, ConversionResult, formats
│   └── Utilities/      Notifications
└── Resources/
    └── Info.plist
```

## 🛡 False Positive Protection

Zestify uses three layers to avoid accidental wheel pops:

1. **Debounce (300ms)** — modifier keys must be held at least 300ms
2. **Drag Pasteboard Check** — only activates if Finder reports an active file drag
3. **Escape Dismiss** — press `Esc` anytime to cancel

## 📄 License

MIT License — see [LICENSE](LICENSE)

---

Made with 🍋 and SwiftUI
