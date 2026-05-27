import SwiftUI
import UIKit

struct InteractivePopGesture: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(InteractivePopGestureEnabler())
    }
}

private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        InteractivePopController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class InteractivePopController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}
