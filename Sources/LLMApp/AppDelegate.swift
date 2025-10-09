import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate app and bring to front
        NSApp.activate(ignoringOtherApps: true)

        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "LLM")
            button.action = #selector(handleStatusBarClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create menu
        setupMenu()

        // Configure popover
        let newPopover = NSPopover()
        newPopover.contentSize = NSSize(width: 400, height: 500)
        newPopover.behavior = .transient
        newPopover.contentViewController = NSHostingController(rootView: QuickChatView())
        popover = newPopover
    }

    func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quick Chat", action: #selector(togglePopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func handleStatusBarClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            statusItem?.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            // Left-click: toggle popover
            togglePopover()
        }
    }

    @objc func showMainWindow() {
        // Close menu if open
        statusItem?.menu = nil
        setupMenu()

        // Find or create main window
        for window in NSApp.windows {
            if window.contentViewController is NSHostingController<ContentView> ||
               window.windowController != nil {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        // If no window found, activate app (SwiftUI will create it)
        NSApp.activate(ignoringOtherApps: true)

        // Give SwiftUI a moment to create the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even when main window is closed (for menu bar icon)
        return false
    }
}
