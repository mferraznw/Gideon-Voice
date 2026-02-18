import AppKit
import SwiftUI

@MainActor
class OverlayWindow: NSPanel {
    private var overlayView: NSHostingView<OverlayView>?
    private var escapeMonitor: Any?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure as non-activating floating panel
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.acceptsMouseMovedEvents = true
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // Add vibrancy
        self.contentView?.wantsLayer = true
        
        // Initial position
        if ConfigManager.shared.overlayOriginX != 0 || ConfigManager.shared.overlayOriginY != 0 {
            self.setFrameOrigin(NSPoint(x: ConfigManager.shared.overlayOriginX, y: ConfigManager.shared.overlayOriginY))
        } else {
            positionTopRightWithInset()
        }
        
        // Create hosting view
        let view = OverlayView()
        overlayView = NSHostingView(rootView: view)
        self.contentView = overlayView
        
        // Add escape key handler
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Escape
                NotificationCenter.default.post(name: .overlayDidDismiss, object: nil)
                self.hide()
                return nil
            }
            return event
        }

    }

    deinit {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }

    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        ConfigManager.shared.saveOverlayOrigin(x: point.x, y: point.y)
    }
    
    func show() {
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        positionTopRightWithInset()
        self.orderFrontRegardless()
        self.alphaValue = 0
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }
    
    func hide(after delay: TimeInterval = 0) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.animateHide()
            }
        } else {
            animateHide()
        }
    }
    
    private func animateHide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
        }
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }

    private func positionTopRightWithInset() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let horizontalInset: CGFloat = 28
        let verticalInset: CGFloat = 20

        let x = visibleFrame.maxX - frame.width - horizontalInset
        let y = visibleFrame.maxY - frame.height - verticalInset
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
