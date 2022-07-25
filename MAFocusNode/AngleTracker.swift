//
//  AngleTracker.swift
//  MAFocusNode
//
//  Created by Mark Kim on 5/25/22.
//

import Foundation
import SceneKit

class AngleTracker {
    weak var trackingNode: SCNNode?

    var trackedNodeReferenceTransform: simd_float4x4?

    var trackedNodeAlignedTransform: simd_float4x4? {
        willSet {
            // reset numbers if plane normal has a sudden change above a certain threshold
            // to smooth out the animations
            // e.g., when traveling from a horizontal plane to a vertical plane
            guard let trackedNodeAlignedTransform = trackedNodeAlignedTransform,
                  let newValue = newValue
            else {
                return
            }
            let currentForwardVector = trackedNodeAlignedTransform.unitForwardVector()
            let currentRightVector = trackedNodeAlignedTransform.unitRightVector()
            let currentPlaneNormalVector = simd_cross(currentForwardVector, currentRightVector)

            let newForwardVector = newValue.unitForwardVector()
            let newRightVector = newValue.unitRightVector()
            let newPlaneNormalVector = simd_cross(newForwardVector, newRightVector)

            // threshold of 10 degrees
            let thresholdRadians = Float(10.0 * .pi / 180.0)
            let dRadians = thetaRadians(currentPlaneNormalVector, newPlaneNormalVector)
            if dRadians > thresholdRadians {
                reset()
            }
        }
    }

    var angularVelocityX: Double {
        return averageAngularVelocityX()
    }

    var angularVelocityY: Double {
        return averageAngularVelocityY()
    }

    var angularVelocityZ: Double {
        return averageAngularVelocityZ()
    }

    var angleX: Double {
        return angleForX()
    }

    var angleY: Double {
        return angleForY()
    }

    var angleZ: Double {
        return angleForZ()
    }

    private var lastAngleX: Double?
    private var lastAngleY: Double?
    private var lastAngleZ: Double?
    private var lastTime: Double?

    private var dwXArray: [Double]
    private var dwYArray: [Double]
    private var dwZArray: [Double]
    private var dtArray: [Double]

    private let capacity: Int = 6

    init(_ trackingNode: SCNNode? = nil, _ trackedNodeReferenceTransform: simd_float4x4? = nil) {
        self.trackingNode = trackingNode
        self.trackedNodeReferenceTransform = trackedNodeReferenceTransform
        self.lastAngleX = nil
        self.lastAngleY = nil
        self.lastAngleZ = nil
        self.lastTime = nil
        self.dwXArray = [Double]()
        self.dwYArray = [Double]()
        self.dwZArray = [Double]()
        self.dtArray = [Double]()
    }

    func updateAt(time: TimeInterval) {
        guard let trackingNode = trackingNode,
              trackingNode.isHidden == false
        else {
            reset()
            return
        }

        let nextAngleX = angleForX()
        let nextAngleY = angleForY()
        let nextAngleZ = angleForZ()
        if nextAngleX.isNaN || nextAngleY.isNaN || nextAngleZ.isNaN {
            print("isNaN")
            return
        }

        update(&dwXArray, &lastAngleX, nextAngleX, true)
        update(&dwYArray, &lastAngleY, nextAngleY, true)
        update(&dwZArray, &lastAngleZ, nextAngleZ, true)
        update(&dtArray, &lastTime, time, false)
    }

    func reset() {
        lastAngleX = nil
        lastAngleY = nil
        lastAngleZ = nil
        lastTime = nil
        dwXArray.removeAll()
        dwYArray.removeAll()
        dwZArray.removeAll()
        dtArray.removeAll()
    }
}

// MARK: - Private Methods

extension AngleTracker {
    private func update(_ dArray: inout [Double], _ last: inout Double?, _ next: Double, _ adjustForAngleDiscontinuities: Bool = false) {
        if dArray.count == capacity {
            dArray.removeFirst()
        }
        if let lastValue = last {
            let currentValue = next
            var dValue = currentValue - lastValue

            if adjustForAngleDiscontinuities {
                if dValue < -.pi {
                    dValue += 2.0 * .pi
                } else if dValue > .pi {
                    dValue -= 2.0 * .pi
                }
            }

            dArray.append(dValue)
            last = currentValue
        } else {
            last = next
        }
    }

    private func averageAngularVelocityX() -> Double {
        guard dwXArray.count == capacity, dtArray.count == capacity else {
            return 0.0
        }
        let totalRadians = dwXArray.reduce(0, +)
        let totalTime = dtArray.reduce(0, +)
        return totalRadians / totalTime
    }

    private func averageAngularVelocityY() -> Double {
        guard dwYArray.count == capacity, dtArray.count == capacity else {
            return 0.0
        }
        let totalRadians = dwYArray.reduce(0, +)
        let totalTime = dtArray.reduce(0, +)
        return totalRadians / totalTime
    }

    private func averageAngularVelocityZ() -> Double {
        guard dwZArray.count == capacity, dtArray.count == capacity else {
            return 0.0
        }
        let totalRadians = dwZArray.reduce(0, +)
        let totalTime = dtArray.reduce(0, +)
        return totalRadians / totalTime
    }

    private func angleForX() -> Double {
        guard let trackingNode = trackingNode,
              trackingNode.isHidden == false,
              let trackedNodeAlignedTransform = trackedNodeAlignedTransform
        else {
            reset()
            return 0.0
        }

        let trackingTransform = trackingNode.simdTransform

        let hypotenuseVector = trackingTransform.translation() - trackedNodeAlignedTransform.translation()
        let adjacentUnitVector = trackedNodeAlignedTransform.unitForwardVector()
        let oppositeVector = oppositeVector(hypotenuseVector: hypotenuseVector, adjacentUnitVector: adjacentUnitVector)
        let angle = thetaRadians(hypotenuseVector, oppositeVector)

        let orientationVector = hypotenuseVector - oppositeVector
        let dotTest = dot(orientationVector, trackingTransform.unitUpVector())
        let adjustedAngle = dotTest > 0.0 ? -angle : angle

        return Double(adjustedAngle)
    }

    // TODO: - solve bug for angle Y for non-aligned transform case
    private func angleForY() -> Double {
        guard let trackingNode = trackingNode,
              trackingNode.isHidden == false,
              let trackedNodeAlignedTransform = trackedNodeAlignedTransform
        else {
            reset()
            return 0.0
        }

        let trackingTransform = trackingNode.simdTransform

        let hypotenuseVector = trackingTransform.translation() - trackedNodeAlignedTransform.translation()
        let adjacentUnitVector = trackedNodeAlignedTransform.unitLeftVector()
        let oppositeVector = oppositeVector(hypotenuseVector: hypotenuseVector, adjacentUnitVector: adjacentUnitVector)
        let angle = thetaRadians(hypotenuseVector, oppositeVector)

        let orientationVector = hypotenuseVector - oppositeVector
        let dotTest = dot(orientationVector, trackingTransform.unitRightVector())
        let adjustedAngle = dotTest > 0.0 ? angle : -angle

        return Double(adjustedAngle)
    }

    private func angleForZ() -> Double {
        guard let trackingNode = trackingNode,
              trackingNode.isHidden == false,
              let trackedNodeAlignedTransform = trackedNodeAlignedTransform
        else {
            reset()
            return 0.0
        }

        // TODO: - implement for angle Z

        return 0.0
    }
}
