import AppKit

// MARK: - Radial Wheel ViewModel
final class RadialWheelViewModel {
    var segments: [WheelSegment]
    var hoveredIndex: Int? = nil
    var sourceFormat: String = "Zestify"
    var onHoverChanged: (() -> Void)?

    init(mode: WheelMode, category: FileCategory = .video, sourceFormat: String = "Zestify") {
        self.segments = WheelSegment.segments(for: mode, category: category)
        self.sourceFormat = sourceFormat
    }

    var hoveredSegment: WheelSegment? {
        guard let idx = hoveredIndex, idx >= 0 && idx < segments.count else { return nil }
        return segments[idx]
    }

    func updateHoverAngle(_ angle: Double, distance: Double) {
        let innerR = 42.0
        let outerR = 148.0

        if distance < innerR || distance > outerR {
            if hoveredIndex != nil {
                hoveredIndex = nil
                onHoverChanged?()
            }
            return
        }

        let count = Double(segments.count)
        let slice = (2 * Double.pi) / count

        // Map angle so index 0 is at top (π/2 in standard coords), going clockwise
        var norm = Double.pi / 2 - angle
        while norm < 0 { norm += 2 * Double.pi }
        while norm >= 2 * Double.pi { norm -= 2 * Double.pi }

        let index = Int(norm / slice) % segments.count
        if hoveredIndex != index {
            hoveredIndex = index
            onHoverChanged?()
        }
    }
}

// MARK: - Radial Wheel NSView (Liquid Glass Design)
final class RadialWheelView: NSView {

    var viewModel: RadialWheelViewModel
    var onPerformDrop: ((WheelSegment, [URL]) -> Void)?
    var onDismiss: (() -> Void)?

    private var scaleAnim: CGFloat = 0.3
    private var animTimer: Timer?

    init(frame: NSRect, viewModel: RadialWheelViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // Register for file drags from Finder
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])

        viewModel.onHoverChanged = { [weak self] in
            self?.needsDisplay = true
        }

        animateIn()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - NSDraggingDestination Implementation

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHoverFromDrag(sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateHoverFromDrag(sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        viewModel.hoveredIndex = nil
        needsDisplay = true
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        var urls: [URL] = []

        if let objects = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !objects.isEmpty {
            urls = objects
        } else if let files = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = files.map { URL(fileURLWithPath: $0) }
        }

        guard !urls.isEmpty else { return false }

        // Determine target segment (hovered, or first if dropped near center)
        let targetSegment = viewModel.hoveredSegment ?? viewModel.segments.first!
        onPerformDrop?(targetSegment, urls)
        return true
    }

    private func updateHoverFromDrag(_ sender: NSDraggingInfo) {
        let pt = convert(sender.draggingLocation, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = Double(pt.x - center.x)
        let dy = Double(pt.y - center.y)
        let dist = sqrt(dx*dx + dy*dy)
        let angle = atan2(dy, dx)
        viewModel.updateHoverAngle(angle, distance: dist)
    }

    // MARK: - Mouse Handlers (Click Support)

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = Double(pt.x - center.x)
        let dy = Double(pt.y - center.y)
        let dist = sqrt(dx*dx + dy*dy)
        let angle = atan2(dy, dx)
        viewModel.updateHoverAngle(angle, distance: dist)
    }

    override func mouseUp(with event: NSEvent) {
        if let seg = viewModel.hoveredSegment {
            // If clicked with files on drag pasteboard
            let pb = NSPasteboard(name: .drag)
            var urls: [URL] = []
            if let objects = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !objects.isEmpty {
                urls = objects
            } else if let files = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
                urls = files.map { URL(fileURLWithPath: $0) }
            }
            if !urls.isEmpty {
                onPerformDrop?(seg, urls)
                return
            }
        }
        onDismiss?()
    }

    // MARK: - Animate In

    private func animateIn() {
        scaleAnim = 0.4
        let start = Date()
        let duration = 0.22
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(elapsed / duration, 1.0)
            let spring = 1.0 - pow(1.0 - progress, 3)
            self.scaleAnim = 0.4 + (1.0 - 0.4) * CGFloat(spring)
            self.needsDisplay = true
            if progress >= 1.0 { t.invalidate() }
        }
    }

    // MARK: - Drawing (Liquid Glass Aesthetic Matching Photo)

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerWheelRadius: CGFloat = 142
        let petalOuterRadius: CGFloat = 136
        let petalInnerRadius: CGFloat = 48
        let centerHubWidth: CGFloat = 86
        let centerHubHeight: CGFloat = 44

        ctx.saveGState()
        // Spring scale animation
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: scaleAnim, y: scaleAnim)
        ctx.translateBy(x: -center.x, y: -center.y)

        // 1. Outer Translucent Glass Ring
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 16, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        let outerCircle = CGPath(ellipseIn: CGRect(x: center.x - outerWheelRadius, y: center.y - outerWheelRadius,
                                                   width: outerWheelRadius * 2, height: outerWheelRadius * 2), transform: nil)
        ctx.setFillColor(NSColor(white: 0.88, alpha: 0.55).cgColor)
        ctx.addPath(outerCircle)
        ctx.fillPath()

        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.65).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(outerCircle)
        ctx.strokePath()
        ctx.restoreGState()

        // 2. Petals (Segments)
        let count = viewModel.segments.count
        let sliceAngle = (2 * CGFloat.pi) / CGFloat(count)
        let angularGap: CGFloat = 0.055 // Clean gap between petals

        for (i, segment) in viewModel.segments.enumerated() {
            let isHovered = (viewModel.hoveredIndex == i)

            // Calculate start and end angle for slice (0 at top, going clockwise)
            let midAngle = (CGFloat.pi / 2) - CGFloat(i) * sliceAngle
            let startAngle = midAngle + (sliceAngle / 2) - (angularGap / 2)
            let endAngle = midAngle - (sliceAngle / 2) + (angularGap / 2)

            let rOut = isHovered ? petalOuterRadius + 2 : petalOuterRadius
            let rIn = petalInnerRadius

            let petalPath = CGMutablePath()
            petalPath.addArc(center: center, radius: rOut, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            petalPath.addArc(center: center, radius: rIn, startAngle: endAngle, endAngle: startAngle, clockwise: false)
            petalPath.closeSubpath()

            ctx.saveGState()

            if isHovered {
                // Active Tangerine Orange Hover (as in photo)
                ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 10, color: NSColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 0.5).cgColor)

                let orangeGradColors = [
                    NSColor(red: 1.0, green: 0.44, blue: 0.06, alpha: 1.0).cgColor, // #FF7010
                    NSColor(red: 0.93, green: 0.28, blue: 0.02, alpha: 1.0).cgColor  // #EC4705
                ] as CFArray
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let grad = CGGradient(colorsSpace: colorSpace, colors: orangeGradColors, locations: [0.0, 1.0]) {
                    ctx.addPath(petalPath)
                    ctx.clip()
                    ctx.drawLinearGradient(grad,
                                           start: CGPoint(x: center.x, y: center.y + rOut),
                                           end: CGPoint(x: center.x, y: center.y - rOut),
                                           options: [])
                }

                // Orange Petal Stroke
                ctx.restoreGState()
                ctx.saveGState()
                ctx.setStrokeColor(NSColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 0.8).cgColor)
                ctx.setLineWidth(1.5)
                ctx.addPath(petalPath)
                ctx.strokePath()
            } else {
                // Frosted White Glass Petal (as in photo)
                ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.08).cgColor)
                ctx.setFillColor(NSColor(white: 0.95, alpha: 0.92).cgColor)
                ctx.addPath(petalPath)
                ctx.fillPath()

                // Subtle frosted glass border
                ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.85).cgColor)
                ctx.setLineWidth(1.0)
                ctx.addPath(petalPath)
                ctx.strokePath()
            }
            ctx.restoreGState()

            // Petal Text Label
            let labelRadius = (petalInnerRadius + petalOuterRadius) / 2
            let labelX = center.x + labelRadius * cos(midAngle)
            let labelY = center.y + labelRadius * sin(midAngle)

            let textColor = isHovered ? NSColor.white : NSColor.black
            let font = NSFont.systemFont(ofSize: 12.5, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let str = NSAttributedString(string: segment.label, attributes: attrs)
            let strSize = str.size()
            str.draw(at: CGPoint(x: labelX - strSize.width / 2, y: labelY - strSize.height / 2))
        }

        // 3. Center Hub (Frosted Glass Pill)
        let hubRect = CGRect(x: center.x - centerHubWidth / 2,
                             y: center.y - centerHubHeight / 2,
                             width: centerHubWidth,
                             height: centerHubHeight)
        let hubPath = CGPath(roundedRect: hubRect, cornerWidth: centerHubHeight / 2, cornerHeight: centerHubHeight / 2, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        ctx.setFillColor(NSColor(white: 0.97, alpha: 0.95).cgColor)
        ctx.addPath(hubPath)
        ctx.fillPath()

        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(hubPath)
        ctx.strokePath()
        ctx.restoreGState()

        // 4. Center Label: Current Target Format or Source
        let centerText: String
        if let hovered = viewModel.hoveredSegment {
            centerText = hovered.label
        } else {
            centerText = viewModel.sourceFormat
        }

        let centerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.5, weight: .bold),
            .foregroundColor: NSColor.black.withAlphaComponent(0.9)
        ]
        let centerStr = NSAttributedString(string: centerText, attributes: centerAttrs)
        let centerSize = centerStr.size()
        centerStr.draw(at: CGPoint(x: center.x - centerSize.width / 2, y: center.y - centerSize.height / 2))

        ctx.restoreGState()
    }

    override var isFlipped: Bool { false }
}
