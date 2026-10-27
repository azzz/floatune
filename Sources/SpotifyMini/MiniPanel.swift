import AppKit
import SwiftUI

/// Floating panel that stays above all windows, never takes focus from the active app
/// and dims after a period without interaction.
@MainActor
final class MiniPanel: NSPanel {
    static let size = NSSize(width: 340, height: 132)
    private static let autosaveName = "SpotifyMiniPanel"
    private static let cornerRadius: CGFloat = 14

    /// Called every time the panel is shown.
    var onPresent: (() -> Void)?
    /// Called every time the panel is hidden.
    var onHide: (() -> Void)?

    private let settings: AppSettings
    private var dimTimer: Timer?
    private var isDimmed = false
    private var mouseInside = false

    init(content: NSView, settings: AppSettings) {
        self.settings = settings
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        // A layer corner radius does not clip behind-window blur; a mask image does.
        background.maskImage = Self.roundedMask(radius: Self.cornerRadius)

        content.frame = background.bounds
        content.autoresizingMask = [.width, .height]
        background.addSubview(content)
        background.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
        contentView = background

        if setFrameUsingName(Self.autosaveName) {
            // The saved frame may come from a build with another panel size; keep its top-left corner.
            setFrame(NSRect(x: frame.minX, y: frame.maxY - Self.size.height,
                            width: Self.size.width, height: Self.size.height), display: false)
        } else {
            placeAtTopRight()
        }
        setFrameAutosaveName(Self.autosaveName)
    }

    override var canBecomeKey: Bool { true }

    /// Shows the panel at full opacity.
    func present() {
        isDimmed = false
        alphaValue = 1
        orderFrontRegardless()
        mouseInside = frame.contains(NSEvent.mouseLocation)
        scheduleDim()
        onPresent?()
    }

    /// Hotkey handler: hidden → shown, dimmed → full opacity, shown → hidden.
    func toggle() {
        if !isVisible {
            present()
        } else if isDimmed {
            wake()
        } else {
            dimTimer?.invalidate()
            orderOut(nil)
            onHide?()
        }
    }

    /// Applies changed dim settings: a dimmed panel takes the new opacity, the timer restarts.
    func settingsDidChange() {
        guard isVisible else { return }
        if isDimmed {
            alphaValue = settings.dimAlpha
        } else {
            scheduleDim()
        }
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .leftMouseDragged, .scrollWheel:
            wake()
        default:
            break
        }
        super.sendEvent(event)
    }

    override func mouseEntered(with event: NSEvent) {
        mouseInside = true
        wake()
    }

    override func mouseExited(with event: NSEvent) {
        mouseInside = false
        scheduleDim()
    }

    private func wake() {
        if isDimmed {
            isDimmed = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                animator().alphaValue = 1
            }
        }
        scheduleDim()
    }

    private func scheduleDim() {
        dimTimer?.invalidate()
        guard !mouseInside else { return }
        dimTimer = Timer.scheduledTimer(withTimeInterval: settings.dimDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.dim() }
        }
    }

    private func dim() {
        guard isVisible, !mouseInside else { return }
        isDimmed = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            animator().alphaValue = settings.dimAlpha
        }
    }

    private func placeAtTopRight() {
        guard let visible = NSScreen.main?.visibleFrame else { return }
        let margin: CGFloat = 16
        setFrameOrigin(NSPoint(
            x: visible.maxX - Self.size.width - margin,
            y: visible.maxY - Self.size.height - margin
        ))
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Hosting view that handles the first click even when its window is not key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
