//
//  PasteOnlyTextView.swift
//  Block-Time
//
//  Created by Nelson on 03/11/2025.
//

import SwiftUI
import UIKit

// MARK: - Paste Only Text View

/// A text view that only allows pasting, preventing keyboard input
struct PasteOnlyTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = NoKeyboardTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Add long press gesture for paste menu
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        textView.addGestureRecognizer(longPress)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: PasteOnlyTextView

        init(_ parent: PasteOnlyTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let textView = gesture.view as? UITextView else { return }

            textView.becomeFirstResponder()
        }
    }
}

// MARK: - No Keyboard Text View

/// Custom UITextView that prevents keyboard from appearing
class NoKeyboardTextView: UITextView {
    override var inputView: UIView? {
        get {
            return UIView() // Return empty view to prevent keyboard
        }
        set {
            // Do nothing
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true // Allow it to become first responder for paste menu
    }

    // Disable AutoFill accessory view
    override var inputAccessoryView: UIView? {
        get {
            return nil
        }
        set {
            // Do nothing
        }
    }

    // Customize edit menu to only show Paste
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            return UIPasteboard.general.hasStrings
        }
        return false
    }
}
