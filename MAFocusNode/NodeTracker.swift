//
//  NodeTracker.swift
//  MAFocusNode
//
//  Created by Mark Kim on 6/1/22.
//

import Foundation
import SceneKit
import ARKit

class NodeTracker: NSObject {
    weak var sceneView: ARSCNView?

    weak var trackedNode: SCNNode? {
        didSet {
            trackedNodePositionTracker.node = trackedNode
        }
    }

    weak var trackingNode: SCNNode? {
        didSet {
            trackingNodeAngleTracker.trackingNode = trackingNode
        }
    }

    // flags
    var trackedNodeIsEnabled: Bool
    var trackedNodeAlignedWithTrackingNode: Bool
    var trackedNodeEnableScaleEffect: Bool
    var trackedNodeEnableRotationEffect: Bool
    var panEnableRotationEffect: Bool

    // trackers
    private(set) var trackedNodePositionTracker: PositionTracker
    private(set) var trackingNodeAngleTracker: AngleTracker

    // transforms
    var initialTransform: simd_float4x4
    private var adjustedPlaneTransform: simd_float4x4
    private var planeRotationTransform: simd_float4x4
    private var rotationAdjustedPlaneTransform: simd_float4x4

    init(sceneView: ARSCNView? = nil) {
        // private
        self.trackedNodePositionTracker = PositionTracker()
        self.trackingNodeAngleTracker = AngleTracker()
        self.initialTransform = matrix_identity_float4x4
        self.adjustedPlaneTransform = matrix_identity_float4x4
        self.planeRotationTransform = matrix_identity_float4x4
        self.rotationAdjustedPlaneTransform = matrix_identity_float4x4

        // public
        self.sceneView = sceneView
        self.trackedNode = nil
        self.trackingNode = nil
        self.trackedNodeIsEnabled = true
        self.trackedNodeAlignedWithTrackingNode = true
        self.trackedNodeEnableScaleEffect = true
        self.trackedNodeEnableRotationEffect = true
        self.panEnableRotationEffect = true
    }

    func updateAt(time: TimeInterval) {
        update(with: trackingNode)
        trackedNodePositionTracker.updateAt(time: time)
        trackingNodeAngleTracker.updateAt(time: time)
    }
}

// MARK: - Node Management

extension NodeTracker {
    func update(with trackingNode: SCNNode?) {
        guard let sceneView = sceneView,
              let trackedNode = trackedNode,
              let trackingNode = trackingNode
        else {
            return
        }

        guard trackedNodeIsEnabled else {
            trackedNode.isHidden = true
            return
        }
        trackedNode.isHidden = false

        // build raycast query
        let trackingNodeOrigin = trackingNode.simdTransform.translation()
        let trackingDirection = trackingNode.simdTransform.unitBackVector()
        let query = ARRaycastQuery(origin: trackingNodeOrigin, direction: trackingDirection, allowing: .existingPlaneGeometry, alignment: .any)

        // raycast
        let results = sceneView.session.raycast(query)
        guard results.count > 0 else {
            trackedNode.isHidden = true
            return
        }

        // get intersected plane
        var match: ARRaycastResult? = nil
        for result in results {
            if result.anchor is ARPlaneAnchor {
                match = result
                break
            }
        }
        guard let match = match else {
            trackedNode.isHidden = true
            return
        }

        // get final transform
        let finalTrackedNodeTransform = updatedTransform(from: match, trackingNode: trackingNode)
        trackedNode.simdTransform = finalTrackedNodeTransform
    }

    private func updatedTransform(from match: ARRaycastResult, trackingNode: SCNNode?) -> simd_float4x4 {
        // determine transforms for trackedNode based on ray cast
        adjustedPlaneTransform = trackedNodeTransform(from: match.worldTransform, targetAlignment: match.targetAlignment)

        if let trackingNode = trackingNode {
            planeRotationTransform = rotationTransformAligningTrackedNodeWithTrackingNode(from: adjustedPlaneTransform, trackingNode: trackingNode)
        }
        rotationAdjustedPlaneTransform = adjustedPlaneTransform * planeRotationTransform

        // update trackedNode angle tracker
        trackingNodeAngleTracker.trackedNodeReferenceTransform = adjustedPlaneTransform
        trackingNodeAngleTracker.trackedNodeAlignedTransform = rotationAdjustedPlaneTransform

        // update final transform for trackedNode
        var finalTrackedNodeTransform = initialTransform

        // scaling effect
        if trackedNodeEnableScaleEffect {
            finalTrackedNodeTransform = angleTrackerScaleXZTransform() * finalTrackedNodeTransform
        }
        // rotation effect
        if trackedNodeEnableRotationEffect {
            finalTrackedNodeTransform = angleTrackerRotationXZTransform() * finalTrackedNodeTransform
        }
        // aligning trackedNode -z-axis to trackingNode +y-axis
        if trackedNodeAlignedWithTrackingNode {
            finalTrackedNodeTransform = planeRotationTransform * finalTrackedNodeTransform
        }

        finalTrackedNodeTransform = adjustedPlaneTransform * finalTrackedNodeTransform

        return finalTrackedNodeTransform
    }

    private func trackedNodeTransform(from matchTransform: simd_float4x4, targetAlignment: ARRaycastQuery.TargetAlignment) -> simd_float4x4 {
        switch targetAlignment {
        case .horizontal:
            // custom behavior i want:
            // * when pointing camera at the ceiling, show orientation "right side up"
            let referenceVector = simd_float3(0, 1, 0)
            let dotTest = dot(referenceVector,matchTransform.unitUpVector())
            if dotTest > 0.0 {
                // pointing at floor; do nothing
                return matchTransform
            } else {
                // pointing at ceiling; flip y-axis by 180 degrees
                let positionTransform = simd_float4x4.translationTransform(matchTransform.translation())

                let rotationQuaternion = simd_quaternion(.pi, simd_float3(0, 1, 0))
                let updatedQuaternion = matchTransform.quaternion() * rotationQuaternion
                let orientationTransform = simd_float4x4(updatedQuaternion)

                let updatedTransform = positionTransform * orientationTransform
                return updatedTransform
            }
        case .vertical:
            return matchTransform
        case .any:
            // shouldn't reach this case
            print("invalid alignment .any: \(targetAlignment)")
            return matchTransform
        @unknown default:
            print("unknown alignment: \(targetAlignment)")
            return matchTransform
        }
    }

    private func rotationTransformAligningTrackedNodeWithTrackingNode(from referenceTransform: simd_float4x4, trackingNode: SCNNode?) -> simd_float4x4 {
        guard let trackingNode = trackingNode else {
            return matrix_identity_float4x4
        }

        let originalTransform = referenceTransform

        // get additional rotation needed to line up trackedNode's backVector with trackingNode's projected upVector
        let referenceVector = trackingNode.simdTransform.unitUpVector() // aka vectorToProject
        let planeVectors = (originalTransform.unitForwardVector(), originalTransform.unitRightVector())
        let planeNormalVector = simd_cross(planeVectors.0, planeVectors.1)
        let referenceOrientationVector = trackingNode.simdTransform.unitForwardVector()
        let rotationTransformTuple = transformForTrackingNodeRotationZ(originalTransform: originalTransform,
                                                                       referenceVector: referenceVector,
                                                                       planeNormalVector: planeNormalVector,
                                                                       referenceOrientationVector: referenceOrientationVector)

        return rotationTransformTuple.0
    }

    // TODO: - fix issue for plane orientation (should use unitUpVector) vs. focus node orientation (uses unitBackVector)
    // returns a tuple containing (rotationTransformY, angleY)
    private func transformForTrackingNodeRotationZ(originalTransform: simd_float4x4,
                                                   referenceVector: simd_float3,
                                                   planeNormalVector: simd_float3,
                                                   referenceOrientationVector: simd_float3) -> (simd_float4x4, Float) {
        let projectedVector = projection(of: referenceVector, using: planeNormalVector)

        let originalBackVector = originalTransform.unitBackVector()
        let adjustedAngle = thetaRadians(projectedVector, originalBackVector)
        let normalProjectedBackVector = simd_cross(projectedVector, originalBackVector)
        let dotTest = dot(referenceOrientationVector, normalProjectedBackVector)
        let adjustedAngleOffset = dotTest > 0.0 ? -1.0 * adjustedAngle : adjustedAngle

        return (simd_float4x4.rotationTransformY(adjustedAngleOffset), adjustedAngleOffset)
    }
}

// MARK: - Animation Transforms

extension NodeTracker {
    private func panRotationXZTransform() -> simd_float4x4 {
        guard trackedNodePositionTracker.node != nil else {
            return matrix_identity_float4x4
        }

        let nodeVelocity = trackedNodePositionTracker.nodeVelocity

        let factorX = Float(1.0 * simd_clamp(nodeVelocity.x, -2.0, 2.0) / 4.5)
        let factorY = Float(1.0 * simd_clamp(nodeVelocity.y, -2.0, 2.0) / 9.0)

        let rotationX = simd_quaternion(factorY, simd_float3(1, 0, 0))
        let rotationZ = simd_quaternion(factorX, simd_float3(0, 0, 1))
        let totalRotation = simd_mul(rotationX, rotationZ)

        return simd_float4x4(totalRotation)
    }

    private func angleTrackerRotationXZTransform() -> simd_float4x4 {
        guard trackingNodeAngleTracker.trackingNode != nil else {
            return matrix_identity_float4x4
        }

        let factorX = Float(1.0 * simd_clamp(trackingNodeAngleTracker.angularVelocityX, -.pi, .pi) / .pi)
        let factorY = Float(-1.0 * simd_clamp(trackingNodeAngleTracker.angularVelocityY, -.pi, .pi) / .pi)

        let rotationX = simd_quaternion(factorX, simd_float3(1, 0, 0))
        let rotationZ = simd_quaternion(factorY, simd_float3(0, 0, 1))
        let totalRotation = simd_mul(rotationX, rotationZ)

        return simd_float4x4(totalRotation)
    }

    private func angleTrackerScaleXZTransform() -> simd_float4x4 {
        guard trackingNodeAngleTracker.trackingNode != nil else {
            return matrix_identity_float4x4
        }

        let baseScale: Float = 0.75

        let angularVelocityX = trackingNodeAngleTracker.angularVelocityX
        let adjustedAngularVelocityX = simd_clamp(abs(angularVelocityX), 0.0, .pi) / .pi
        let scaleFactorX: Float = Float(baseScale + Float(0.75 * adjustedAngularVelocityX))

        let angularVelocityY = trackingNodeAngleTracker.angularVelocityY
        let adjustedAngularVelocityY = simd_clamp(abs(angularVelocityY), 0.0, .pi) / .pi
        let scaleFactorY: Float = Float(baseScale + Float(0.75 * adjustedAngularVelocityY))

        let scaleX: Float = scaleFactorX
        let scaleY: Float = 1.0
        let scaleZ: Float = scaleFactorY
        let scale = simd_float3(x: scaleX, y: scaleY, z: scaleZ)

        return simd_float4x4.scaleTransform(scale)
    }
}
