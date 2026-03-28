import AppKit

enum AppMenuController {
    static func install() {
        NSApp.mainMenu = buildMainMenu()
    }

    private static func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = buildApplicationMenu()
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = buildEditMenu()
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    private static func buildApplicationMenu() -> NSMenu {
        let menu = NSMenu(title: "VoiceInput")

        let appName = ProcessInfo.processInfo.processName
        let aboutItem = NSMenuItem(title: "About \(appName)", action: #selector(AppMenuActionRouter.openAbout(_:)), keyEquivalent: "")
        aboutItem.target = AppMenuActionRouter.shared
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        menu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        ).keyEquivalentModifierMask = [.command, .option]
        menu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        return menu
    }

    private static func buildEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")

        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return menu
    }
}

@MainActor
private final class AppMenuActionRouter: NSObject {
    static let shared = AppMenuActionRouter()

    @objc func openAbout(_ sender: Any?) {
        AboutWindowController.shared.show()
    }
}
