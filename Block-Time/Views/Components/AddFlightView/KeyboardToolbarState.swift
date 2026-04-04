import SwiftUI

/// Shared state for the single keyboard toolbar in AddFlightView.
/// Each field reports its focus and registers its clear action here.
@Observable
final class KeyboardToolbarState {
    var isAnyFieldFocused: Bool = false
    var onClear: (() -> Void)? = nil

    func fieldDidFocus(clear: @escaping () -> Void) {
        isAnyFieldFocused = true
        onClear = clear
    }

    func fieldDidBlur() {
        // Don't set isAnyFieldFocused = false here; the toolbar
        // hides itself via the keyboard dismissal, not via this flag.
        // Resetting between fields causes a toolbar flash.
    }
}
