//
//  PositionTracker.swift
//  MAFocusNode
//
//  Created by Mark Kim on 5/29/22.
//

import Foundation
import SceneKit

class PositionTracker {
    weak var node: SCNNode?

    var position: simd_float3 {
        guard let node = node else {
            return simd_float3(0, 0, 0)
        }
        let translation = node.simdTransform.translation()
        return simd_float3(translation.x, translation.y, translation.z)
    }

    var velocity: simd_float3 {
        return averageVelocity()
    }

    var nodeVelocity: simd_float3 {
        return averageNodeVelocity()
    }

    private var lastX: Double?
    private var lastY: Double?
    private var lastZ: Double?
    private var lastTime: Double?
    private var dxArray: [Double]
    private var dyArray: [Double]
    private var dzArray: [Double]
    private var dtArray: [Double]
    private let capacity: Int = 6

    init(_ node: SCNNode? = nil) {
        self.node = node
        self.lastX = nil
        self.lastY = nil
        self.lastZ = nil
        self.lastTime = nil
        self.dxArray = [Double]()
        self.dyArray = [Double]()
        self.dzArray = [Double]()
        self.dtArray = [Double]()
    }

    func updateAt(time: TimeInterval) {
        guard let node = node, node.isHidden == false else {
            reset()
            return
        }

        let translation = node.simdTransform.translation()

        update(&dxArray, &lastX, Double(translation.x))
        update(&dyArray, &lastY, Double(translation.y))
        update(&dzArray, &lastZ, Double(translation.z))
        update(&dtArray, &lastTime, time)
    }

    func reset() {
        lastX = nil
        lastY = nil
        lastZ = nil
        lastTime = nil
        dxArray.removeAll()
        dyArray.removeAll()
        dzArray.removeAll()
        dtArray.removeAll()
    }
}

// MARK: - Private Methods

extension PositionTracker {
    private func update(_ dArray: inout [Double], _ last: inout Double?, _ next: Double) {
        if dArray.count == capacity {
            dArray.removeFirst()
        }
        if let lastValue = last {
            let currentValue = next
            let dValue = currentValue - lastValue
            dArray.append(dValue)
            last = currentValue
        } else {
            last = next
        }
    }

    private func averageVelocity() -> simd_float3 {
        guard node != nil else {
            return simd_float3(0, 0, 0)
        }
        guard dxArray.count == capacity,
              dyArray.count == capacity,
              dzArray.count == capacity,
              dtArray.count == capacity else {
            return simd_float3(0, 0, 0)
        }
        let totalDx = dxArray.reduce(0, +)
        let totalDy = dyArray.reduce(0, +)
        let totalDz = dzArray.reduce(0, +)
        let totalDt = dtArray.reduce(0, +)

        let dXdt = Float(totalDx / totalDt)
        let dYdt = Float(totalDy / totalDt)
        let dZdt = Float(totalDz / totalDt)

        return simd_float3(dXdt, dYdt, dZdt)
    }

    private func averageNodeVelocity() -> simd_float3 {
        guard let node = node else {
            return simd_float3(0, 0, 0)
        }

        let velocity = averageVelocity()
        let transform = node.simdTransform

        let rightVector = transform.unitRightVector()
        let upVector = transform.unitUpVector()
        let forwardVector = transform.unitForwardVector()

        let rightComponent = dot(velocity, rightVector)
        let upComponent = dot(velocity, upVector)
        let forwardComponent = dot(velocity, forwardVector)

        return simd_float3(rightComponent, upComponent, forwardComponent)
    }
}
