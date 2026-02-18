import AppKit
import SwiftUI

@MainActor
class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    init() {
        setupStatusItem()
        setupMenu()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: "GideonTalk")
            button.imagePosition = .imageOnly
        }
        
        updateIcon(for: .idle)
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu?.addItem(statusMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        menu?.addItem(NSMenuItem(title: "Toggle Listening", action: #selector(toggleListening), keyEquivalent: "g"))
        menu?.items.last?.keyEquivalentModifierMask = [.command, .shift]
        
        menu?.addItem(NSMenuItem(title: "New Conversation", action: #selector(newConversation), keyEquivalent: "n"))
        
        menu?.addItem(NSMenuItem.separator())
        
        menu?.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        
        menu?.addItem(NSMenuItem.separator())
        
        menu?.addItem(NSMenuItem(title: "Quit GideonTalk", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func updateIcon(for state: ConversationState) {
        guard let button = statusItem?.button else { return }
        
        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic.slash", accessibilityDescription: "Idle")
        case .listening:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Listening")
        case .thinking:
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Thinking")
        case .speaking:
            button.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Speaking")
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
        }
        
        // Update status text
        if let menu = menu, let item = menu.item(withTag: 100) {
            item.title = state.statusText
        }
    }
    
    @objc private func toggleListening() {
        // This will be handled by hotkey manager
        NotificationCenter.default.post(name: .toggleListening, object: nil)
    }
    
    @objc private func newConversation() {
        ConversationManager.shared.clearHistory()
    }
    
    @objc private func openSettings() {
        // Open settings window
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let toggleListening = Notification.Name("toggleListening")
}
