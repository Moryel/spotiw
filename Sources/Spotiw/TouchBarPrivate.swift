import AppKit

/// Private DFRFoundation / AppKit calls that let a background app put its own
/// bar on the Touch Bar (the same mechanism Pock and MTMR use).
/// Everything is looked up at runtime so a missing symbol degrades to a no-op.
enum TouchBarPrivate {
    private static let dfrHandle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY)

    private static func dfrSymbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle = dfrHandle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }

    static var isAvailable: Bool {
        dfrHandle != nil
            && class_getClassMethod(NSTouchBar.self, NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")) != nil
    }

    /// Shows or hides an item in the Control Strip (right side of the Touch Bar).
    static func setControlStripPresence(_ identifier: NSTouchBarItem.Identifier, _ present: Bool) {
        typealias Function = @convention(c) (NSString, Bool) -> Void
        dfrSymbol("DFRElementSetControlStripPresenceForIdentifier", as: Function.self)?(identifier.rawValue as NSString, present)
    }

    /// Adds the "X" on the left of a system modal bar that returns to the normal Touch Bar.
    static func setShowsCloseBox(_ shows: Bool) {
        typealias Function = @convention(c) (Bool) -> Void
        dfrSymbol("DFRSystemModalShowsCloseBoxWhenFrontMost", as: Function.self)?(shows)
    }

    static func addSystemTrayItem(_ item: NSTouchBarItem) {
        callClassMethod(on: NSTouchBarItem.self, "addSystemTrayItem:", item)
    }

    static func removeSystemTrayItem(_ item: NSTouchBarItem) {
        callClassMethod(on: NSTouchBarItem.self, "removeSystemTrayItem:", item)
    }

    /// placement 0 keeps the Control Strip visible, 1 uses the full width.
    static func presentSystemModal(_ touchBar: NSTouchBar, placement: Int64, trayIdentifier: NSTouchBarItem.Identifier) {
        let selector = NSSelectorFromString("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:")
        guard let method = class_getClassMethod(NSTouchBar.self, selector) else { return }
        typealias Function = @convention(c) (AnyObject, Selector, NSTouchBar, Int64, NSString) -> Void
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        function(NSTouchBar.self, selector, touchBar, placement, trayIdentifier.rawValue as NSString)
    }

    static func minimizeSystemModal(_ touchBar: NSTouchBar) {
        callClassMethod(on: NSTouchBar.self, "minimizeSystemModalTouchBar:", touchBar)
    }

    static func dismissSystemModal(_ touchBar: NSTouchBar) {
        callClassMethod(on: NSTouchBar.self, "dismissSystemModalTouchBar:", touchBar)
    }

    private static func callClassMethod(on cls: AnyClass, _ selectorName: String, _ argument: AnyObject) {
        let selector = NSSelectorFromString(selectorName)
        guard let method = class_getClassMethod(cls, selector) else { return }
        typealias Function = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
        function(cls, selector, argument)
    }
}
