//
//  EdgeSwipeBack.swift
//  Leftover
//
//  Every screen here is a plain SwiftUI view swapped in by a ZStack +
//  @State flag (see ContentView), not a NavigationStack push — so there's
//  no interactivePopGestureRecognizer backing the left-edge "swipe back"
//  iOS users expect, even though pushTransition visually looks like a
//  nav push. This wraps a UIScreenEdgePanGestureRecognizer (the same
//  recognizer UINavigationController uses) so list-style screens get
//  that gesture back without a full navigation-architecture rewrite.
//

import SwiftUI
import UIKit

private struct EdgeSwipeBackView: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UIScreenEdgePanGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        recognizer.edges = .left
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }

        @objc func handle(_ recognizer: UIScreenEdgePanGestureRecognizer) {
            guard recognizer.state == .ended,
                  recognizer.translation(in: recognizer.view).x > 60 else { return }
            action()
        }
    }
}

extension View {
    /// Adds a left-edge swipe-to-go-back gesture, matching the system
    /// convention. Only use on screens without their own horizontal
    /// swipe semantics — the main card-swipe screen intentionally
    /// leaves this off since a left swipe already means "delete" there.
    func edgeSwipeBack(action: @escaping () -> Void) -> some View {
        background(EdgeSwipeBackView(action: action))
    }
}
