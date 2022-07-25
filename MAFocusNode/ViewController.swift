//
//  ViewController.swift
//  MAFocusNode
//
//  Created by Mark Kim on 7/24/22.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!

    var focusNode: SCNNode!
    var focusNodeTracker: NodeTracker = NodeTracker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initScene()
        initARSession()
        initFocusNode()
        initFocusNodeTracker()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {}

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {}

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {}
}

// MARK: - Session Management (ARSessionObserver)

extension ViewController {
    func initARSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("AR World Tracking not supported")
            return
        }

        let config = ARWorldTrackingConfiguration()

        config.worldAlignment = .gravity
        config.providesAudioData = false
        config.planeDetection = [.horizontal, .vertical]
        config.isLightEstimationEnabled = true
        config.environmentTexturing = .automatic

        sceneView.session.run(config)
    }

    func resetARSession() {
        let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
        config.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {}

    func session(_ session: ARSession, didFailWithError error: Error) {}

    func sessionWasInterrupted(_ session: ARSession) {}

    func sessionInterruptionEnded(_ session: ARSession) {}
}

// MARK: - Render Management (SCNSceneRendererDelegate)

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.focusNodeTracker.updateAt(time: time)
        }
    }
}

// MARK: - Scene Management

extension ViewController {
    func initScene() {
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
}

// MARK: - Node Management

extension ViewController {
    func initFocusNode() {
        let focusScene = SCNScene(named: "art.scnassets/Focus.scn")!
        focusNode = focusScene.rootNode.childNode(withName: "Focus", recursively: false)
        sceneView.scene.rootNode.addChildNode(focusNode)
    }

    func initFocusNodeTracker() {
        focusNodeTracker.sceneView = sceneView
        focusNodeTracker.trackedNode = focusNode
        focusNodeTracker.trackingNode = sceneView.pointOfView!
    }
}
