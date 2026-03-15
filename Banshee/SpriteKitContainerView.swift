import SwiftUI
import SpriteKit

struct SpriteKitContainerView: UIViewRepresentable {
    let scene: GameScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        view.backgroundColor = UIColor.clear

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        if uiView.scene !== scene {
            uiView.presentScene(scene)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene)
    }

    final class Coordinator: NSObject {
        private weak var scene: GameScene?
        private var startScale: CGFloat = 1.0
        private var lastPanTranslation: CGPoint = .zero

        init(scene: GameScene) {
            self.scene = scene
            super.init()
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let scene else { return }
            switch recognizer.state {
            case .began:
                startScale = scene.camera?.xScale ?? 1.0
            case .changed:
                let rawScale = startScale / recognizer.scale
                let clamped = max(0.5, min(2.5, rawScale))
                scene.setCameraScale(clamped)
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let scene, let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            switch recognizer.state {
            case .began:
                lastPanTranslation = .zero
            case .changed:
                let delta = CGPoint(x: translation.x - lastPanTranslation.x, y: -(translation.y - lastPanTranslation.y))
                scene.panCamera(by: delta)
                lastPanTranslation = translation
            default:
                lastPanTranslation = .zero
            }
        }
    }
}
