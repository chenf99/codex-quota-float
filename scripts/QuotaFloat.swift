import AppKit
import Foundation
import UniformTypeIdentifiers

struct WindowStatus {
    let status: String
    let capturedAtText: String
    let accountLine: String
    let bucketLine: String
    let primaryLine: String
    let primaryRemaining: Double
    let secondaryLine: String
    let secondaryRemaining: Double
    let extraLine: String
    let errorLine: String?

    var riskRemaining: Double {
        let values = [primaryRemaining, secondaryRemaining].filter { $0 > 0 }
        return values.min() ?? 0
    }

    static let loading = WindowStatus(
        status: "loading",
        capturedAtText: "--",
        accountLine: "Reading Codex account",
        bucketLine: "Codex",
        primaryLine: "5h left --",
        primaryRemaining: 0,
        secondaryLine: "1w left --",
        secondaryRemaining: 0,
        extraLine: "",
        errorLine: nil
    )
}

enum QuotaSkin: String, CaseIterable {
    case image = "image"
    case classic = "classic"

    func title(imageSkinTitle: String) -> String {
        switch self {
        case .image:
            return imageSkinTitle
        case .classic:
            return "Classic Glass"
        }
    }
}

private let skinDefaultsKey = "CodexQuotaFloatSkin"

final class QuotaBadgeView: NSView {
    var status = WindowStatus.loading {
        didSet { needsDisplay = true }
    }
    var skin: QuotaSkin = .image {
        didSet {
            UserDefaults.standard.set(skin.rawValue, forKey: skinDefaultsKey)
            needsDisplay = true
        }
    }
    var avatarImage: NSImage? {
        didSet { needsDisplay = true }
    }
    var avatarInitials = "CF" {
        didSet { needsDisplay = true }
    }
    var imageSkinTitle = "Image Skin" {
        didSet { needsDisplay = true }
    }
    var isExpanded = false {
        didSet {
            expansionProgress = isExpanded ? 1 : 0
            needsDisplay = true
        }
    }
    var expansionProgress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    var isRefreshing = false {
        didSet { needsDisplay = true }
    }
    var onHoverChanged: ((Bool) -> Void)?
    var onRefreshRequested: (() -> Void)?
    var onQuitRequested: (() -> Void)?
    var onChooseImageSkinRequested: (() -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragEnded: (() -> Void)?
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowFrame: NSRect?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if containsVisualPoint(point, tolerance: 0) {
            onHoverChanged?(true)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard expansionProgress < 0.08 else { return }
        let point = convert(event.locationInWindow, from: nil)
        if containsVisualPoint(point, tolerance: 0) {
            onHoverChanged?(true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowFrame = window?.frame
        onDragStarted?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartMouseLocation,
              let dragStartWindowFrame else {
            return
        }
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - dragStartMouseLocation.x
        let deltaY = currentMouse.y - dragStartMouseLocation.y
        let nextFrame = NSRect(
            x: dragStartWindowFrame.origin.x + deltaX,
            y: dragStartWindowFrame.origin.y + deltaY,
            width: dragStartWindowFrame.width,
            height: dragStartWindowFrame.height
        )
        window.setFrame(nextFrame, display: true, animate: false)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartWindowFrame = nil
        onDragEnded?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onHoverChanged?(true)
        NSMenu.popUpContextMenu(makeContextMenu(), with: event, for: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        makeContextMenu()
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: "Codex Quota")

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !isRefreshing
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let skinItem = NSMenuItem(title: "Skin", action: nil, keyEquivalent: "")
        let skinMenu = NSMenu(title: "Skin")
        for option in QuotaSkin.allCases {
            let item = NSMenuItem(title: option.title(imageSkinTitle: imageSkinTitle), action: #selector(selectSkinFromMenu), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = option == skin ? .on : .off
            skinMenu.addItem(item)
        }
        skinMenu.addItem(.separator())
        let chooseImageItem = NSMenuItem(title: "Choose Image...", action: #selector(chooseImageSkinFromMenu), keyEquivalent: "")
        chooseImageItem.target = self
        skinMenu.addItem(chooseImageItem)
        menu.addItem(skinItem)
        menu.setSubmenu(skinMenu, for: skinItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Codex Quota", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func refreshFromMenu() {
        onRefreshRequested?()
    }

    @objc private func selectSkinFromMenu(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let selected = QuotaSkin(rawValue: rawValue) else {
            return
        }
        skin = selected
    }

    @objc private func chooseImageSkinFromMenu() {
        onChooseImageSkinRequested?()
    }

    @objc private func quitFromMenu() {
        onQuitRequested?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let progress = max(0, min(1, expansionProgress))
        let eased = smoothStep(progress)
        let surfaceRect = bounds.insetBy(dx: lerp(5, 4, eased), dy: lerp(5, 4, eased))
        drawSurface(in: surfaceRect, progress: eased)

        let collapsedBadge = NSRect(
            x: surfaceRect.maxX - min(surfaceRect.width, surfaceRect.height),
            y: surfaceRect.maxY - min(surfaceRect.width, surfaceRect.height),
            width: min(surfaceRect.width, surfaceRect.height),
            height: min(surfaceRect.width, surfaceRect.height)
        )
        let expandedBadge = NSRect(x: surfaceRect.minX + 18, y: surfaceRect.maxY - 70, width: 52, height: 52)
        let badgeRect = interpolateRect(from: collapsedBadge, to: expandedBadge, progress: eased)
        drawBadge(in: badgeRect, progress: eased)

        let contentAlpha = smoothStep(max(0, min(1, (progress - 0.58) / 0.42)))
        drawPanelContent(in: surfaceRect, alpha: contentAlpha)
    }

    func containsVisualPoint(_ point: NSPoint, tolerance: CGFloat = 0) -> Bool {
        let progress = max(0, min(1, expansionProgress))
        let eased = smoothStep(progress)
        let baseRect = bounds.insetBy(dx: lerp(5, 4, eased), dy: lerp(5, 4, eased))
        let rect = baseRect.insetBy(dx: -tolerance, dy: -tolerance)
        let radius = max(0, lerp(min(baseRect.width, baseRect.height) / 2, 24, eased) + tolerance)
        return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).contains(point)
    }

    private func drawSurface(in rect: NSRect, progress: CGFloat) {
        NSGraphicsContext.saveGraphicsState()

        let shadow = NSShadow()
        shadow.shadowBlurRadius = lerp(16, 28, progress)
        shadow.shadowOffset = NSSize(width: 0, height: lerp(-4, -10, progress))
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25 + 0.04 * progress)
        shadow.set()

        let radius = lerp(min(rect.width, rect.height) / 2, 24, progress)
        let surface = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        if skin == .image, let avatarImage {
            NSColor.black.withAlphaComponent(0.92).setFill()
            surface.fill()
            NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)
            NSGraphicsContext.saveGraphicsState()
            surface.addClip()
            drawAspectFillImage(avatarImage, in: rect)
            drawImageOverlay(in: rect, progress: progress)
            drawImageSurfaceDetail(in: rect, radius: radius, progress: progress)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            surfaceGradient(progress: progress).draw(in: surface, angle: 132)
            NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)
            if skin == .image {
                NSGraphicsContext.saveGraphicsState()
                surface.addClip()
                drawImageSurfaceDetail(in: rect, radius: radius, progress: progress)
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        NSColor.white.withAlphaComponent(0.12 + 0.02 * progress).setStroke()
        surface.lineWidth = 1
        surface.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBadge(in rect: NSRect, progress: CGFloat) {
        if skin == .image {
            drawAvatarBadge(in: rect, progress: progress)
        } else {
            let badgeBackgroundAlpha = lerp(0, 1, progress)
            if badgeBackgroundAlpha > 0.01 {
                NSGradient(colors: [
                    NSColor(hex: 0x1E293B, alpha: badgeBackgroundAlpha),
                    NSColor(hex: 0x020617, alpha: badgeBackgroundAlpha),
                ])?.draw(in: NSBezierPath(ovalIn: rect), angle: 145)
            }
        }

        let inset = lerp(6, 5.5, progress)
        let ringWidth = lerp(4.8, 4.5, progress)
        drawRing(in: rect.insetBy(dx: inset, dy: inset), percent: status.riskRemaining, width: ringWidth)

        let percent = status.status == "ok" ? "\(Int(status.riskRemaining))%" : "--"
        drawCenteredText(
            percent,
            in: rect,
            font: NSFont.monospacedDigitSystemFont(ofSize: lerp(percent.count > 3 ? 15 : 17, 15, progress), weight: .semibold),
            color: .white,
            shadow: textShadow()
        )

        if isRefreshing {
            let dotRect = NSRect(x: rect.maxX - 12, y: rect.maxY - 12, width: 8, height: 8)
            metricColor(status.riskRemaining).setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }
    }

    private func drawPanelContent(in rect: NSRect, alpha: CGFloat) {
        guard alpha > 0.01 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(alpha)

        let h = rect.height

        drawText(
            "Codex Quota",
            in: NSRect(x: rect.minX + 82, y: rect.minY + h - 40, width: 160, height: 22),
            font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            color: .white,
            alignment: .left
        )
        drawText(
            status.accountLine,
            in: NSRect(x: rect.minX + 82, y: rect.minY + h - 60, width: rect.width - 104, height: 18),
            font: NSFont.systemFont(ofSize: 11, weight: .regular),
            color: NSColor.white.withAlphaComponent(0.62),
            alignment: .left
        )

        let updated = isRefreshing ? "Updating" : status.capturedAtText
        drawPill(text: updated, in: NSRect(x: rect.maxX - 86, y: rect.maxY - 41, width: 68, height: 24))

        drawText(
            status.bucketLine,
            in: NSRect(x: rect.minX + 18, y: rect.maxY - 88, width: rect.width - 36, height: 18),
            font: NSFont.systemFont(ofSize: 12, weight: .medium),
            color: NSColor.white.withAlphaComponent(0.84),
            alignment: .left
        )

        drawMetric(
            line: status.primaryLine,
            percent: status.primaryRemaining,
            y: rect.maxY - 122,
            in: rect,
            accent: metricColor(status.primaryRemaining)
        )
        drawMetric(
            line: status.secondaryLine,
            percent: status.secondaryRemaining,
            y: rect.maxY - 158,
            in: rect,
            accent: metricColor(status.secondaryRemaining)
        )

        let footer = status.errorLine ?? status.extraLine
        drawText(
            footer,
            in: NSRect(x: rect.minX + 18, y: rect.minY + 14, width: rect.width - 36, height: 16),
            font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
            color: status.errorLine == nil ? NSColor.white.withAlphaComponent(0.48) : NSColor(hex: 0xFCA5A5),
            alignment: .left
        )

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawMetric(line: String, percent: Double, y: CGFloat, in rect: NSRect, accent: NSColor) {
        drawText(
            line,
            in: NSRect(x: rect.minX + 18, y: y + 12, width: rect.width - 36, height: 16),
            font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            color: NSColor.white.withAlphaComponent(0.78),
            alignment: .left
        )

        let barRect = NSRect(x: rect.minX + 18, y: y, width: rect.width - 36, height: 7)
        NSColor.white.withAlphaComponent(skin == .image ? 0.12 : 0.10).setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 3.5, yRadius: 3.5).fill()

        let fillWidth = max(7, barRect.width * CGFloat(max(0, min(100, percent)) / 100))
        let fillRect = NSRect(x: barRect.minX, y: barRect.minY, width: fillWidth, height: barRect.height)
        accent.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 3.5, yRadius: 3.5).fill()
    }

    private func drawPill(text: String, in rect: NSRect) {
        NSColor.white.withAlphaComponent(skin == .image ? 0.11 : 0.09).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
        drawCenteredText(
            text,
            in: rect,
            font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
            color: NSColor.white.withAlphaComponent(0.62)
        )
    }

    private func drawAvatarBadge(in rect: NSRect, progress: CGFloat) {
        let oval = NSBezierPath(ovalIn: rect)
        NSGraphicsContext.saveGraphicsState()
        oval.addClip()

        if let avatarImage {
            drawAspectFillImage(avatarImage, in: rect)
        } else {
            NSGradient(colors: [
                NSColor(hex: 0x1F2937),
                NSColor(hex: 0x0F766E),
            ])?.draw(in: rect, angle: 135)
            drawCenteredText(
                avatarInitials,
                in: rect,
                font: NSFont.systemFont(ofSize: lerp(17, 14, progress), weight: .semibold),
                color: .white,
                shadow: textShadow()
            )
        }

        NSGradient(colors: [
            NSColor.black.withAlphaComponent(0.18),
            NSColor.black.withAlphaComponent(0.52),
        ])?.draw(in: rect, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.18).setStroke()
        oval.lineWidth = 1
        oval.stroke()
    }

    private func drawAspectFillImage(_ image: NSImage, in rect: NSRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, rect.width > 0, rect.height > 0 else { return }

        let imageRatio = imageSize.width / imageSize.height
        let targetRatio = rect.width / rect.height
        let sourceRect: NSRect

        if imageRatio > targetRatio {
            let cropWidth = imageSize.height * targetRatio
            sourceRect = NSRect(
                x: (imageSize.width - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: imageSize.height
            )
        } else {
            let cropHeight = imageSize.width / targetRatio
            sourceRect = NSRect(
                x: 0,
                y: (imageSize.height - cropHeight) / 2,
                width: imageSize.width,
                height: cropHeight
            )
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func surfaceGradient(progress: CGFloat) -> NSGradient {
        switch skin {
        case .image:
            return NSGradient(colors: [
                NSColor(hex: 0x181A1B, alpha: 0.98),
                NSColor(hex: 0x12312E, alpha: 0.98),
                NSColor(hex: 0x2A1E22, alpha: 0.97),
            ]) ?? NSGradient(starting: NSColor(hex: 0x181A1B), ending: NSColor(hex: 0x12312E))!
        case .classic:
            return NSGradient(colors: [
                NSColor(hex: 0x172033, alpha: 0.98),
                NSColor(hex: 0x0F172A, alpha: 0.96),
            ]) ?? NSGradient(starting: NSColor(hex: 0x172033), ending: NSColor(hex: 0x0F172A))!
        }
    }

    private func drawImageOverlay(in rect: NSRect, progress: CGFloat) {
        NSGradient(colors: [
            NSColor.black.withAlphaComponent(0.60),
            NSColor(hex: 0x12312E, alpha: 0.34),
            NSColor.black.withAlphaComponent(0.68),
        ])?.draw(in: rect, angle: 0)

        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.12 * progress),
            NSColor.clear,
            NSColor.black.withAlphaComponent(0.36),
        ])?.draw(in: rect, angle: -90)
    }

    private func drawImageSurfaceDetail(in rect: NSRect, radius: CGFloat, progress: CGFloat) {
        let topLine = NSBezierPath()
        topLine.move(to: NSPoint(x: rect.minX + radius * 0.75, y: rect.maxY - 1.25))
        topLine.line(to: NSPoint(x: rect.maxX - radius * 0.75, y: rect.maxY - 1.25))
        topLine.lineWidth = 1
        NSColor(hex: 0xF8FAFC, alpha: 0.11 + 0.04 * progress).setStroke()
        topLine.stroke()

        guard progress > 0.12 else { return }
        let accentWidth = min(rect.width - 40, 92 + 72 * progress)
        let accentRect = NSRect(x: rect.minX + 20, y: rect.minY + 8, width: accentWidth, height: 2)
        NSGradient(colors: [
            NSColor(hex: 0xFBBF24, alpha: 0.34),
            NSColor(hex: 0x34D399, alpha: 0.26),
        ])?.draw(in: NSBezierPath(roundedRect: accentRect, xRadius: 1, yRadius: 1), angle: 0)
    }

    private func drawRing(in rect: NSRect, percent: Double, width: CGFloat) {
        let base = NSBezierPath(ovalIn: rect)
        base.lineWidth = width
        NSColor.white.withAlphaComponent(0.12).setStroke()
        base.stroke()

        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let clamped = max(0, min(100, percent))
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - CGFloat(360 * clamped / 100),
            clockwise: true
        )
        arc.lineWidth = width
        arc.lineCapStyle = .round
        metricColor(percent).setStroke()
        arc.stroke()
    }

    private func metricColor(_ percent: Double) -> NSColor {
        if skin == .image {
            switch percent {
            case 60...:
                return NSColor(hex: 0x45E0A8)
            case 30..<60:
                return NSColor(hex: 0x7DD3FC)
            case 12..<30:
                return NSColor(hex: 0xFBBF24)
            default:
                return NSColor(hex: 0xFB7185)
            }
        } else {
            switch percent {
            case 60...:
                return NSColor(hex: 0x34D399)
            case 30..<60:
                return NSColor(hex: 0x38BDF8)
            case 12..<30:
                return NSColor(hex: 0xF59E0B)
            default:
                return NSColor(hex: 0xF87171)
            }
        }
    }

    private func textShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        return shadow
    }

    private func smoothStep(_ t: CGFloat) -> CGFloat {
        t * t * (3 - 2 * t)
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    private func interpolateRect(from start: NSRect, to end: NSRect, progress: CGFloat) -> NSRect {
        NSRect(
            x: lerp(start.origin.x, end.origin.x, progress),
            y: lerp(start.origin.y, end.origin.y, progress),
            width: lerp(start.width, end.width, progress),
            height: lerp(start.height, end.height, progress)
        )
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    private func drawCenteredText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, shadow: NSShadow? = nil) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        if let shadow {
            attrs[.shadow] = shadow
        }
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let textSize = attributed.size()
        let textRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2 - 0.5,
            width: textSize.width,
            height: textSize.height
        ).integral
        attributed.draw(in: textRect)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let collapsedSize = NSSize(width: 68, height: 68)
    private let expandedSize = NSSize(width: 348, height: 210)
    private let statusScript: String
    private let avatarImagePath: String?
    private let initialSkin: QuotaSkin
    private let avatarInitials: String
    private let imageSkinTitle: String
    private let interval: TimeInterval
    private let topmost: Bool
    private var window: NSWindow!
    private var badgeView: QuotaBadgeView!
    private var timer: Timer?
    private var animationTimer: Timer?
    private var hoverMonitorTimer: Timer?
    private var isFetching = false
    private var isDraggingWindow = false
    private var collapseWorkItem: DispatchWorkItem?
    private var targetExpanded = false
    private var hoverGeneration = 0

    init(statusScript: String, avatarImagePath: String?, initialSkin: QuotaSkin, avatarInitials: String, imageSkinTitle: String, interval: TimeInterval, topmost: Bool) {
        self.statusScript = statusScript
        self.avatarImagePath = avatarImagePath
        self.initialSkin = initialSkin
        self.avatarInitials = avatarInitials
        self.imageSkinTitle = imageSkinTitle
        self.interval = interval
        self.topmost = topmost
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildWindow()
        fetchStatus()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchStatus()
        }
    }

    private func buildWindow() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 80, y: 80, width: 1280, height: 800)
        let origin = NSPoint(x: screenFrame.maxX - collapsedSize.width - 26, y: screenFrame.maxY - collapsedSize.height - 72)
        window = NSWindow(
            contentRect: NSRect(origin: origin, size: collapsedSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.level = topmost ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        badgeView = QuotaBadgeView(frame: NSRect(origin: .zero, size: collapsedSize))
        badgeView.avatarImage = avatarImagePath.flatMap { NSImage(contentsOfFile: $0) }
        badgeView.avatarInitials = avatarInitials
        badgeView.imageSkinTitle = imageSkinTitle
        if let storedSkin = UserDefaults.standard.string(forKey: skinDefaultsKey).flatMap(QuotaSkin.init(rawValue:)) {
            badgeView.skin = storedSkin
        } else {
            badgeView.skin = initialSkin
        }
        badgeView.onHoverChanged = { [weak self] expanded in
            self?.setExpanded(expanded)
        }
        badgeView.onRefreshRequested = { [weak self] in
            self?.fetchStatus()
        }
        badgeView.onQuitRequested = {
            NSApp.terminate(nil)
        }
        badgeView.onChooseImageSkinRequested = { [weak self] in
            self?.chooseImageSkin()
        }
        badgeView.onDragStarted = { [weak self] in
            self?.beginWindowDrag()
        }
        badgeView.onDragEnded = { [weak self] in
            self?.endWindowDrag()
        }
        window.contentView = badgeView
        window.makeKeyAndOrderFront(nil)
    }

    private func chooseImageSkin() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Choose Codex Quota Skin"
        panel.message = "Choose an image for the floating ball and expanded panel."
        panel.prompt = "Use Image"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "bmp", "webp"].compactMap {
            UTType(filenameExtension: $0)
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.applyImageSkin(from: url)
        }
    }

    private func applyImageSkin(from sourceURL: URL) {
        do {
            let fileManager = FileManager.default
            let configDirectory = userConfigDirectory()
            let skinDirectory = configDirectory.appendingPathComponent("skins", isDirectory: true)
            let configFile = configDirectory.appendingPathComponent("config.env")

            try fileManager.createDirectory(at: skinDirectory, withIntermediateDirectories: true)
            let skinImage = uniqueSkinImageURL(for: sourceURL, in: skinDirectory)
            try writePNGImage(from: sourceURL, to: skinImage)

            let title = defaultImageSkinTitle(for: sourceURL.path)
            let config = [
                "export CODEX_QUOTA_SKIN_IMAGE=\(zshQuoted(skinImage.path))",
                "export CODEX_QUOTA_SKIN_TITLE=\(zshQuoted(title))",
                "",
            ].joined(separator: "\n")
            try config.write(to: configFile, atomically: true, encoding: .utf8)

            badgeView.avatarImage = NSImage(contentsOf: skinImage)
            badgeView.imageSkinTitle = title
            badgeView.skin = .image
            badgeView.needsDisplay = true
        } catch {
            showSkinError(error)
        }
    }

    private func writePNGImage(from sourceURL: URL, to destinationURL: URL) throws {
        if let image = NSImage(contentsOf: sourceURL),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try pngData.write(to: destinationURL, options: .atomic)
            return
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func userConfigDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_QUOTA_CONFIG_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex-quota-float", isDirectory: true)
    }

    private func zshQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func showSkinError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could Not Set Image Skin"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func uniqueSkinImageURL(for sourceURL: URL, in skinDirectory: URL) -> URL {
        let rawBase = sourceURL.deletingPathExtension().lastPathComponent
        let sanitized = rawBase
            .map { character -> Character in
                if character.isLetter || character.isNumber || character == "-" || character == "_" {
                    return character
                }
                return "-"
            }
        let compactBase = String(sanitized)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        let base = compactBase.isEmpty ? "image-skin" : compactBase
        let timestamp = skinTimestamp()
        var candidate = skinDirectory.appendingPathComponent("\(base)-\(timestamp).png")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = skinDirectory.appendingPathComponent("\(base)-\(timestamp)-\(suffix).png")
            suffix += 1
        }
        return candidate
    }

    private func skinTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }

    private func setExpanded(_ expanded: Bool) {
        guard !isDraggingWindow else { return }
        if !expanded {
            scheduleCollapse(after: 0.045)
            return
        }
        hoverGeneration += 1
        cancelScheduledCollapse()
        guard pointerIsInsideVisualShape(tolerance: 0) else { return }
        startHoverMonitor()
        animateExpansion(to: true)
    }

    private func scheduleCollapse(after delay: TimeInterval) {
        guard collapseWorkItem == nil else { return }
        let generation = hoverGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWorkItem = nil
            guard !self.isDraggingWindow else { return }
            guard generation == self.hoverGeneration else { return }
            if !self.pointerIsInsideStableHoverRegion() {
                self.animateExpansion(to: false)
            }
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func startHoverMonitor() {
        guard hoverMonitorTimer == nil else { return }
        let timer = Timer(timeInterval: 0.035, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard !self.isDraggingWindow else { return }
            if self.targetExpanded && !self.pointerIsInsideStableHoverRegion() {
                self.scheduleCollapse(after: 0.045)
            } else if self.collapseWorkItem != nil {
                self.cancelScheduledCollapse()
            }
        }
        hoverMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelScheduledCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    private func stopHoverMonitor() {
        hoverMonitorTimer?.invalidate()
        hoverMonitorTimer = nil
    }

    private func pointerIsInsideVisualShape(tolerance: CGFloat = 0) -> Bool {
        guard let contentView = window.contentView else { return false }
        let screenPoint = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let viewPoint = badgeView.convert(windowPoint, from: contentView)
        return badgeView.containsVisualPoint(viewPoint, tolerance: tolerance)
    }

    private func pointerIsInsideStableHoverRegion() -> Bool {
        let tolerance: CGFloat = targetExpanded || badgeView.expansionProgress > 0.2 ? 4 : 0
        return pointerIsInsideVisualShape(tolerance: tolerance)
    }

    private func animateExpansion(to expanded: Bool) {
        guard !isDraggingWindow else { return }
        guard targetExpanded != expanded || animationTimer != nil || badgeView.isExpanded != expanded else { return }
        if !expanded && pointerIsInsideStableHoverRegion() {
            return
        }
        targetExpanded = expanded
        animationTimer?.invalidate()

        let anchor = NSPoint(x: window.frame.maxX, y: window.frame.maxY)
        let targetSize = expanded ? expandedSize : collapsedSize
        let targetFrame = frame(for: targetSize, anchoredAt: anchor)
        let startProgress = badgeView.expansionProgress
        let targetProgress: CGFloat = expanded ? 1 : 0
        let duration: TimeInterval = expanded ? 0.085 : 0.07
        let startTime = Date.timeIntervalSinceReferenceDate

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: expanded ? .easeOut : .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }

        let newTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let elapsed = Date.timeIntervalSinceReferenceDate - startTime
            let raw = max(0, min(1, elapsed / duration))
            let eased = expanded ? self.easeOutCubic(raw) : self.easeInOutCubic(raw)

            self.badgeView.expansionProgress = startProgress + (targetProgress - startProgress) * CGFloat(eased)

            if raw >= 1 {
                timer.invalidate()
                self.animationTimer = nil
                self.badgeView.isExpanded = expanded
                self.badgeView.expansionProgress = targetProgress
                self.window.setFrame(targetFrame, display: true, animate: false)
                if !expanded {
                    self.stopHoverMonitor()
                }
            }
        }
        animationTimer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
        newTimer.fire()
    }

    private func beginWindowDrag() {
        isDraggingWindow = true
        cancelScheduledCollapse()
        animationTimer?.invalidate()
        animationTimer = nil
        stopHoverMonitor()
        window.setFrame(window.frame, display: true, animate: false)
    }

    private func endWindowDrag() {
        isDraggingWindow = false
        if targetExpanded {
            startHoverMonitor()
            badgeView.isExpanded = true
            badgeView.expansionProgress = 1
        } else if pointerIsInsideVisualShape(tolerance: 0) {
            animateExpansion(to: true)
        }
    }

    private func frame(for size: NSSize, anchoredAt topRight: NSPoint) -> NSRect {
        NSRect(
            x: topRight.x - size.width,
            y: topRight.y - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func easeOutCubic(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    private func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    private func fetchStatus() {
        guard !isFetching else { return }
        isFetching = true
        badgeView.isRefreshing = true

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [statusScript, "--json"]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        process.terminationHandler = { [weak self] proc in
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                self?.isFetching = false
                self?.badgeView.isRefreshing = false
                if proc.terminationStatus != 0 && outData.isEmpty {
                    let errorText = String(data: errData, encoding: .utf8) ?? "collector exited with status \(proc.terminationStatus)"
                    self?.badgeView.status = WindowStatus.error(errorText)
                    return
                }
                self?.decodeAndApply(outData)
            }
        }

        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
                if process.isRunning {
                    process.terminate()
                }
            }
        } catch {
            isFetching = false
            badgeView.isRefreshing = false
            badgeView.status = WindowStatus.error(error.localizedDescription)
        }
    }

    private func decodeAndApply(_ data: Data) {
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                badgeView.status = WindowStatus.error("collector returned non-object JSON")
                return
            }
            badgeView.status = WindowStatus(json: object)
        } catch {
            let text = String(data: data, encoding: .utf8) ?? ""
            badgeView.status = WindowStatus.error("JSON parse failed: \(error.localizedDescription). \(text)")
        }
    }
}

extension WindowStatus {
    init(json: [String: Any]) {
        let status = json["status"] as? String ?? "unknown"
        let capturedAtText = json["capturedAtText"] as? String ?? "--"
        let account = json["account"] as? [String: Any]
        let email = account?["email"] as? String ?? "unknown account"
        let accountPlan = account?["planType"] as? String ?? "unknown"
        let buckets = json["buckets"] as? [[String: Any]] ?? []
        let bucket = buckets.first ?? [:]
        let rawName = bucket["displayName"] as? String ?? "Codex"
        let name = rawName == "codex" ? "Codex" : rawName
        let plan = bucket["planType"] as? String ?? accountPlan
        let primary = bucket["primary"] as? [String: Any] ?? [:]
        let secondary = bucket["secondary"] as? [String: Any] ?? [:]
        let primaryRemaining = Self.percent(primary["remainingPercent"])
        let secondaryRemaining = Self.percent(secondary["remainingPercent"])
        let primaryWindow = primary["windowLabel"] as? String ?? "window"
        let secondaryWindow = secondary["windowLabel"] as? String ?? "window"
        let primaryReset = primary["resetsAtText"] as? String ?? "--"
        let secondaryReset = secondary["resetsAtText"] as? String ?? "--"
        let extraCount = max(0, buckets.count - 1)
        let errors = json["errors"] as? [String] ?? []

        self.status = status
        self.capturedAtText = capturedAtText
        self.accountLine = "\(email) · Codex \(plan.capitalized)"
        self.bucketLine = name == "Codex" ? "Codex quota bucket" : "\(name) bucket"
        self.primaryLine = "\(primaryWindow) left \(Int(primaryRemaining))% · resets \(primaryReset)"
        self.primaryRemaining = primaryRemaining
        self.secondaryLine = "\(secondaryWindow) left \(Int(secondaryRemaining))% · resets \(secondaryReset)"
        self.secondaryRemaining = secondaryRemaining
        self.extraLine = extraCount > 0 ? "\(extraCount) extra bucket: GPT-5.3-Codex-Spark" : "Local app-server source"
        self.errorLine = status == "ok" ? nil : (errors.first ?? "status unavailable")
    }

    static func error(_ message: String) -> WindowStatus {
        WindowStatus(
            status: "error",
            capturedAtText: "--",
            accountLine: "Codex quota unavailable",
            bucketLine: "Collector error",
            primaryLine: "5h left --",
            primaryRemaining: 0,
            secondaryLine: "1w left --",
            secondaryRemaining: 0,
            extraLine: "",
            errorLine: message
        )
    }

    private static func percent(_ value: Any?) -> Double {
        if let intValue = value as? Int {
            return Double(max(0, min(100, intValue)))
        }
        if let doubleValue = value as? Double {
            return max(0, min(100, doubleValue))
        }
        return 0
    }
}

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}

func renderPreview(prefix: String, avatarImagePath: String?, skin: QuotaSkin, avatarInitials: String, imageSkinTitle: String) -> Bool {
    let sample = WindowStatus(
        status: "ok",
        capturedAtText: "14:24:18",
        accountLine: "user@example.com · Codex Pro",
        bucketLine: "Codex quota bucket",
        primaryLine: "5h left 93% · resets 16:03",
        primaryRemaining: 93,
        secondaryLine: "1w left 27% · resets 06-14 16:18",
        secondaryRemaining: 27,
        extraLine: "1 extra bucket: GPT-5.3-Codex-Spark",
        errorLine: nil
    )
    let previews: [(String, NSSize, Bool)] = [
        ("collapsed", NSSize(width: 68, height: 68), false),
        ("expanded", NSSize(width: 348, height: 210), true),
    ]

    for (suffix, size, expanded) in previews {
        let view = QuotaBadgeView(frame: NSRect(origin: .zero, size: size))
        view.status = sample
        view.avatarImage = avatarImagePath.flatMap { NSImage(contentsOfFile: $0) }
        view.avatarInitials = avatarInitials
        view.imageSkinTitle = imageSkinTitle
        view.skin = skin
        view.isExpanded = expanded
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return false
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        view.draw(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        let url = URL(fileURLWithPath: "\(prefix)-\(suffix).png")
        do {
            try data.write(to: url)
        } catch {
            return false
        }
    }
    return true
}

func renderAnimation(prefix: String, avatarImagePath: String?, skin: QuotaSkin, avatarInitials: String, imageSkinTitle: String) -> Bool {
    let sample = WindowStatus(
        status: "ok",
        capturedAtText: "14:34:18",
        accountLine: "user@example.com · Codex Pro",
        bucketLine: "Codex quota bucket",
        primaryLine: "5h left 91% · resets 16:03",
        primaryRemaining: 91,
        secondaryLine: "1w left 27% · resets 06-14 16:18",
        secondaryRemaining: 27,
        extraLine: "1 extra bucket: GPT-5.3-Codex-Spark",
        errorLine: nil
    )
    let collapsed = NSSize(width: 68, height: 68)
    let expanded = NSSize(width: 348, height: 210)
    let steps: [CGFloat] = [0, 0.15, 0.3, 0.5, 0.72, 1]

    for (index, progress) in steps.enumerated() {
        let eased = progress * progress * (3 - 2 * progress)
        let size = NSSize(
            width: collapsed.width + (expanded.width - collapsed.width) * eased,
            height: collapsed.height + (expanded.height - collapsed.height) * eased
        )
        let view = QuotaBadgeView(frame: NSRect(origin: .zero, size: size))
        view.status = sample
        view.avatarImage = avatarImagePath.flatMap { NSImage(contentsOfFile: $0) }
        view.avatarInitials = avatarInitials
        view.imageSkinTitle = imageSkinTitle
        view.skin = skin
        view.expansionProgress = progress
        view.isExpanded = progress >= 1
        view.expansionProgress = progress
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width.rounded(.up)),
            pixelsHigh: Int(size.height.rounded(.up)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return false
        }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        view.draw(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        do {
            try data.write(to: URL(fileURLWithPath: String(format: "%@-%02d.png", prefix, index)))
        } catch {
            return false
        }
    }
    return true
}

func argumentValue(_ name: String) -> String? {
    let args = CommandLine.arguments
    for index in args.indices where args[index] == name && index + 1 < args.count {
        return args[index + 1]
    }
    return nil
}

func defaultImageSkinTitle(for imagePath: String?) -> String {
    guard let imagePath, !imagePath.isEmpty else {
        return "Image Skin"
    }
    let fileName = URL(fileURLWithPath: imagePath).deletingPathExtension().lastPathComponent
    let cleaned = fileName
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "_", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "Image Skin" : cleaned.capitalized
}

let statusScript = argumentValue("--status-script") ?? "./scripts/codex_quota_status.py"
let avatarImagePath = argumentValue("--avatar-image")
let avatarInitials = argumentValue("--avatar-initials") ?? "CF"
let imageSkinTitle = argumentValue("--image-skin-title") ?? defaultImageSkinTitle(for: avatarImagePath)
let initialSkin = argumentValue("--skin").flatMap(QuotaSkin.init(rawValue:)) ?? .image
let interval = TimeInterval(argumentValue("--interval").flatMap(Double.init) ?? 60)
let topmost = !CommandLine.arguments.contains("--normal-window")

let app = NSApplication.shared
if let previewPrefix = argumentValue("--render-preview") {
    exit(renderPreview(prefix: previewPrefix, avatarImagePath: avatarImagePath, skin: initialSkin, avatarInitials: avatarInitials, imageSkinTitle: imageSkinTitle) ? 0 : 1)
}
if let animationPrefix = argumentValue("--render-animation") {
    exit(renderAnimation(prefix: animationPrefix, avatarImagePath: avatarImagePath, skin: initialSkin, avatarInitials: avatarInitials, imageSkinTitle: imageSkinTitle) ? 0 : 1)
}
let delegate = AppDelegate(
    statusScript: statusScript,
    avatarImagePath: avatarImagePath,
    initialSkin: initialSkin,
    avatarInitials: avatarInitials,
    imageSkinTitle: imageSkinTitle,
    interval: interval,
    topmost: topmost
)
app.delegate = delegate
app.run()
