import AppKit
import SwiftUI

@MainActor
class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?
    
    init() {
        setupStatusItem()
        setupMenu()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = nil
            button.title = "⚔️"
        }
        updateIcon(for: .idle)
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "Ready", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu?.addItem(statusMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(title: "Toggle Listening", action: #selector(toggleListening), keyEquivalent: "g")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu?.addItem(toggleItem)
        
        let newConversationItem = NSMenuItem(title: "New Conversation", action: #selector(newConversation), keyEquivalent: "n")
        newConversationItem.target = self
        menu?.addItem(newConversationItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit GideonTalk", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    func updateIcon(for state: ConversationState) {
        guard let button = statusItem?.button else { return }

        button.image = nil
        button.title = "⚔️"
        button.attributedTitle = NSAttributedString(
            string: "⚔️",
            attributes: [
                .foregroundColor: tintColor(for: state),
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        
        // Update status text
        if let menu = menu, let item = menu.item(withTag: 100) {
            item.title = state.statusText
        }
    }

    private func tintColor(for state: ConversationState) -> NSColor {
        switch state {
        case .idle:
            return NSColor.secondaryLabelColor.withAlphaComponent(0.6)
        case .listening:
            return NSColor(red: 14/255, green: 165/255, blue: 163/255, alpha: 1)
        case .thinking:
            return NSColor(red: 212/255, green: 168/255, blue: 83/255, alpha: 1)
        case .speaking:
            return NSColor(red: 56/255, green: 189/255, blue: 248/255, alpha: 1)
        case .error:
            return NSColor.systemRed
        }
    }
    
    @objc private func toggleListening() {
        // This will be handled by hotkey manager
        NotificationCenter.default.post(name: .toggleListening, object: nil)
    }
    
    @objc private func newConversation() {
        ConversationManager.shared.clearHistory()
        StateManager.shared.currentTranscript = ""
        StateManager.shared.currentResponse = ""
    }
    
    @objc private func openSettings() {
        // Open settings window
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow?.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let toggleListening = Notification.Name("toggleListening")
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let overlayDidDismiss = Notification.Name("overlayDidDismiss")
}
