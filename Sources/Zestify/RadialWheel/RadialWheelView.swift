import AppKit

// MARK: - Radial Wheel ViewModel
final class RadialWheelViewModel {
    var segments: [WheelSegment]
    var hoveredIndex: Int? = nil
    var onHoverChanged: (() -> Void)?

    init(mode: WheelMode) {
        self.segments = WheelSegment.segments(for: mode)
    }

    func updateHoverAngle(_ angle: Double) {
        let count = Double(segments.count)
        let slice = (2 * Double.pi) / count
        // Map angle: atan2 gives 0=right, π/2=up in screen coords
        // We want 0 at top, going clockwise
        var normalized = -angle + Double.pi / 2
        if normalized < 0 { normalized += 2 * Double.pi }
        if normalized >= 2 * Double.pi { normalized -= 2 * Double.pi }
        let index = Int(normalized / slice) % segments.count
        if hoveredIndex != index {
            hoveredIndex = index
            onHoverChanged?()
        }
    }
}

// MARK: - Radial Wheel NSView (Pure AppKit)
final class RadialWheelView: NSView {

    var viewModel: RadialWheelViewModel
    var onSelect: ((WheelSegment) -> Void)?
    var onDismiss: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var scaleAnim: CGFloat = 0.3
    private var timer: Timer?

    init(frame: NSRect, viewModel: RadialWheelViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        viewModel.onHoverChanged = { [weak self] in
            self?.needsDisplay = true
        }

        setupTracking()
        animateIn()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Tracking
    private func setupTracking() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = Double(pt.x - center.x)
        let dy = Double(pt.y - center.y)
        let angle = atan2(dy, dx)
        viewModel.updateHoverAngle(angle)
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = Double(pt.x - center.x)
        let dy = Double(pt.y - center.y)
        let dist = sqrt(dx*dx + dy*dy)
        let innerR = 52.0
        let outerR = Double(min(bounds.width, bounds.height) / 2) - 4

        if dist > innerR && dist < outerR {
            if let idx = viewModel.hoveredIndex, idx < viewModel.segments.count {
                onSelect?(viewModel.segments[idx])
            }
        } else {
            onDismiss?()
        }
    }

    // MARK: - Animate In
    private func animateIn() {
        scaleAnim = 0.3
        let start = Date()
        let duration = 0.35
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            let elapsed = Date().timeIntervalSince(start)
            let progress = min(elapsed / duration, 1.0)
            // Spring-like easing
            let spring = 1 - pow(1 - progress, 3)
            self.scaleAnim = 0.3 + (1.0 - 0.3) * CGFloat(spring)
            self.needsDisplay = true
            if progress >= 1.0 { t.invalidate() }
        }
    }

    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerRadius = CGFloat(min(bounds.width, bounds.height) / 2) - 4
        let innerRadius: CGFloat = 52

        // Apply scale animation from center
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: scaleAnim, y: scaleAnim)
        ctx.translateBy(x: -center.x, y: -center.y)

        let count = viewModel.segments.count
        let sliceAngle = 2 * CGFloat.pi / CGFloat(count)
        // Start at top (π/2) going clockwise means we subtract
        let startOffset = CGFloat.pi / 2

        for (i, segment) in viewModel.segments.enumerated() {
            let startAngle = startOffset - CGFloat(i) * sliceAngle
            let endAngle = startAngle - sliceAngle
            let isHovered = viewModel.hoveredIndex == i

            // Pick color
            let color = isHovered ? segment.hoverNSColor : segment.nsColor

            // Draw pie slice
            let path = CGMutablePath()
            path.move(to: center)
            path.addArc(center: center, radius: outerRadius,
                        startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.addArc(center: center, radius: innerRadius,
                        startAngle: endAngle, endAngle: startAngle, clockwise: false)
            path.closeSubpath()

            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()

            // Stroke
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(1)
            ctx.addPath(path)
            ctx.strokePath()

            // Icon text at mid-arc
            let midAngle = startAngle - sliceAngle / 2
            let iconR = (innerRadius + outerRadius) / 2 + (isHovered ? 4 : 0)
            let iconX = center.x + iconR * cos(midAngle)
            let iconY = center.y + iconR * sin(midAngle)

            drawLabel(segment.label, at: CGPoint(x: iconX, y: iconY - 8), ctx: ctx, hovered: isHovered)
            drawIcon(segment.icon, at: CGPoint(x: iconX, y: iconY + 8), ctx: ctx, hovered: isHovered)
        }

        // Center circle (hub)
        let hubPath = CGPath(ellipseIn: CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                               width: innerRadius*2, height: innerRadius*2), transform: nil)
        ctx.setFillColor(NSColor(white: 0.12, alpha: 0.95).cgColor)
        ctx.addPath(hubPath)
        ctx.fillPath()

        // Center label
        drawCenterText("Zestify", at: CGPoint(x: center.x, y: center.y - 7), ctx: ctx)
        drawCenterEmoji("🍋", at: CGPoint(x: center.x, y: center.y + 10), ctx: ctx)

        ctx.restoreGState()
    }

    private func drawLabel(_ text: String, at point: CGPoint, ctx: CGContext, hovered: Bool) {
        let fontSize: CGFloat = hovered ? 10 : 9
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white.withAlphaComponent(0.95)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        str.draw(at: CGPoint(x: point.x - size.width/2, y: point.y - size.height/2))
    }

    private func drawIcon(_ systemName: String, at point: CGPoint, ctx: CGContext, hovered: Bool) {
        let config = NSImage.SymbolConfiguration(pointSize: hovered ? 15 : 13, weight: .semibold)
        let img = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        if let img = img {
            let rect = CGRect(x: point.x - img.size.width/2, y: point.y - img.size.height/2,
                              width: img.size.width, height: img.size.height)
            NSGraphicsContext.saveGraphicsState()
            NSColor.white.set()
            img.draw(in: rect)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawCenterText(_ text: String, at point: CGPoint, ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        str.draw(at: CGPoint(x: point.x - size.width/2, y: point.y - size.height/2))
    }

    private func drawCenterEmoji(_ emoji: String, at point: CGPoint, ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18)
        ]
        let str = NSAttributedString(string: emoji, attributes: attrs)
        let size = str.size()
        str.draw(at: CGPoint(x: point.x - size.width/2, y: point.y - size.height/2))
    }

    override var isFlipped: Bool { false }
}
