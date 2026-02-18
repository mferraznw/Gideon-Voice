import AppKit
import SwiftUI

@MainActor
class OverlayWindow: NSPanel {
    private var overlayView: NSHostingView<OverlayView>?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure as non-activating floating panel
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.acceptsMouseMovedEvents = true
        
        // Add vibrancy
        self.contentView?.wantsLayer = true
        
        // Position at top center
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - 400) / 2
            let y = screenFrame.height - 250
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Create hosting view
        let view = OverlayView()
        overlayView = NSHostingView(rootView: view)
        self.contentView = overlayView
        
        // Add escape key handler
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                self.hide()
                return nil
            }
            return event
        }
    }
    
    func show() {
        self.makeKeyAndOrderFront(nil)
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
}
