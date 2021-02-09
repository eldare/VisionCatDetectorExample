//
//  ViewController.swift
//  ARKit_Vision_Example
//
//  Created by Eldar Eliav on 06/02/2021.
//

import UIKit
import ARKit
import RealityKit

// This is just an educational example.
// A good example of how to properly implement this topic
// please checkout the ARCarGuidePoC project: https://github.com/eldare/ARCarGuidePoC

class ViewController: UIViewController {
    @IBOutlet var arView: ARView!

    private let viewModel = ViewModel()  // SEE STEP 0
    private var isARReady = true

    lazy private var breadEntity: EntityContainer = {
        let rkScene = try! Bread.load_Bread()
        let entity = EntityContainer()
        entity.add(children: rkScene.sliceEntities)
        entity.isEnabled = false
        arView.scene.addAnchor(entity)
        return entity
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // STEP 2.
        // Setup AR Session with World Tracking Configuration

        setupARSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // STEP 3.
        // Setup and start Coaching

        setupCoachingOverlay(with: arView.session)
    }

    private func setupARSession() {
        arView.session.delegate = self
        let arConfig = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            // on iPhone XS and above - person occlusion supported
            arConfig.frameSemantics.insert(.personSegmentationWithDepth)
        }
        arView.session.run(arConfig)
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isARReady else { return }

        // STEP 5.
        // Incoming ARKit frame, lets search it.
        // This is a heavy operation, and should be minimize as much as possible.
        // Even 1/10 cycles is ok.

        viewModel.search(in: frame) { [weak self] result, arFrame in
            guard let self = self else { return }

            // STEP 10.
            // We got a response from search - continue only if valid result

            guard let result = result, result.isCat else {
                self.breadEntity.notFound()
                return
            }

            // STEP 11.
            // Cat found! Adjust bounding box for display

            let displayBoundingBox = result.rawBoundingBox.flippedCoordinates

            // STEP 12.
            // Raycast through the center of the display bounding box
            // until a plane is reached. Any plane.

            let centerPoint = CGPoint(x: displayBoundingBox.midX,
                                      y: displayBoundingBox.midY)

            let raycastQuery = arFrame.raycastQuery(
                from: centerPoint,
                allowing: .estimatedPlane,
                alignment: .any
            )

            let raycastResults = self.arView.session.raycast(raycastQuery)
            guard let firstRaycastResult = raycastResults.first else {
                // no raycast hit result
                return
            }

            // STEP 13.
            // Update RealityKit bread entity position the screen - at the raycast result.

            let realWorldMatrix = firstRaycastResult.worldTransform
            // simd_float4x4 matrix.
            // Contains information on intersection with the first relevant plane in the real world:
            // - position
            // - rotation,
            // - scale

            let simd3_positionVector: SIMD3<Float> = [  // we only care about the position
                realWorldMatrix.columns.3.x,
                realWorldMatrix.columns.3.y,
                realWorldMatrix.columns.3.z
            ]

            self.breadEntity.position = simd3_positionVector  // simd3 position vector

            // STEP 14.
            // rotate the RealityKit bread entity to face the camera

            self.breadEntity.look(
                at: self.arView.cameraTransform.translation,
                from: self.breadEntity.position(relativeTo: nil),
                relativeTo: nil
            )

            // a custom way to manage threshold of the entity show/hide state
            self.breadEntity.found()
        }
    }
}

extension ViewController: ARCoachingOverlayViewDelegate {

    // STEP 4.
    // Now that Coaching is active, ARKit can turn it on / off as often as required.
    // We must always init `isARReady = true`, since it will never be called for ARKit Replay (Debug) -
    // Edit Scheme -> Run -> Options -> ARKit Reply data

    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        print("coaching started")
        isARReady = false
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        print("coaching done")
        isARReady = true
    }
}

extension ARCoachingOverlayViewDelegate where Self: UIViewController {
    func setupCoachingOverlay(with arSession: ARSession,
                              goal: ARCoachingOverlayView.Goal = .anyPlane) {
        print("preparing coaching")
        let coachingOverlay = ARCoachingOverlayView()

        coachingOverlay.session = arSession
        coachingOverlay.delegate = self

        // We define where Coaching is displayed on the screen.
        // Coaching is dismissed once the goal is met - our default goal is .anyPlane

        view.addSubview(coachingOverlay)

        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor),
        ])

        coachingOverlay.activatesAutomatically = true
        coachingOverlay.goal = goal
    }
}

extension CGRect {
    var flippedCoordinates: CGRect {
        var flippedRect = self.applying(CGAffineTransform(scaleX: 1, y: -1))
        flippedRect = flippedRect.applying(CGAffineTransform(translationX: 0, y: 1))
        return flippedRect
    }
}

class EntityContainer: Entity, HasAnchoring {
    private let maxThreshold = 5
    private var threshold = 0 {
        didSet {
            isEnabled = threshold > 0
        }
    }

    func add(children: [Entity]) {
        children.forEach { addChild($0) }
    }

    func notFound() {
        guard threshold > 0 else { return }
        threshold -= 1
    }

    func found() {
        threshold = maxThreshold
    }
}
