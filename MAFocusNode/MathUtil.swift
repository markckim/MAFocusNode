//
//  MathUtil.swift
//  MAFocusNode
//
//  Created by Mark Kim on 5/18/22.
//

import ARKit

struct UnitVector {
    static let right = simd_float3(1, 0, 0)
    static let left = simd_float3(-1, 0, 0)
    static let up = simd_float3(0, 1, 0)
    static let down = simd_float3(0, -1, 0)
    static let forward = simd_float3(0, 0, 1)
    static let back = simd_float3(0, 0, -1)
}

extension simd_float4x4 {
    func translation() -> simd_float3 {
        return simd_float3(self.columns.3.x, self.columns.3.y, self.columns.3.z)
    }

    func quaternion() -> simd_quatf {
      return simd_quatf(self)
    }

    func unitRightVector() -> simd_float3 {
        let vector = simd_float3(columns.0.x, columns.0.y, columns.0.z)
        return simd_normalize(vector)
    }

    func unitLeftVector() -> simd_float3 {
        let vector = unitRightVector()
        return -1.0 * vector
    }

    func unitUpVector() -> simd_float3 {
        let vector = simd_float3(columns.1.x, columns.1.y, columns.1.z)
        return simd_normalize(vector)
    }

    func unitDownVector() -> simd_float3 {
        let vector = unitUpVector()
        return -1.0 * vector
    }

    func unitForwardVector() -> simd_float3 {
        let vector = simd_float3(columns.2.x, columns.2.y, columns.2.z)
        return simd_normalize(vector)
    }

    func unitBackVector() -> simd_float3 {
        let vector = unitForwardVector()
        return -1.0 * vector
    }

    static func translationTransform(_ translation: simd_float3) -> simd_float4x4 {
        let x: Float = translation.x
        let y: Float = translation.y
        let z: Float = translation.z
        return simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(x, y, z, 1)
        )
    }

    static func shearTransformYZ(_ yz: Float) -> simd_float4x4 {
        return shearTransform(yz: yz)
    }

    static func shearTransformYX(_ yx: Float) -> simd_float4x4 {
        return shearTransform(yx: yx)
    }

    static func shearTransform(xy: Float = 0, xz: Float = 0, yz: Float = 0, yx: Float = 0, zx: Float = 0, zy: Float = 0) -> simd_float4x4 {
        return simd_float4x4(
            simd_float4(1,  yx, zx, 0),
            simd_float4(xy, 1,  zy, 0),
            simd_float4(xz, yz, 1,  0),
            simd_float4(0,  0,  0,  1)
        )
    }

    static func scaleTransform(_ scale: simd_float3) -> simd_float4x4 {
        return simd_float4x4(
            simd_float4(scale.x,    0,          0,          0),
            simd_float4(0,          scale.y,    0,          0),
            simd_float4(0,          0,          scale.z,    0),
            simd_float4(0,          0,          0,          1)
        )
    }

    static func rotationTransformX(_ radians: Float) -> simd_float4x4 {
        return simd_float4x4(
            simd_float4(1,              0,              0,              0),
            simd_float4(0,              cos(radians),   sin(radians),   0),
            simd_float4(0,              -sin(radians),  cos(radians),   0),
            simd_float4(0,              0,              0,              1))
    }

    static func rotationTransformY(_ radians: Float) -> simd_float4x4 {
        return simd_float4x4(
            simd_float4(cos(radians),   0,              -sin(radians),  0),
            simd_float4(0,              1,              0,              0),
            simd_float4(sin(radians),   0,              cos(radians),   0),
            simd_float4(0,              0,              0,              1))
    }

    static func rotationTransformZ(_ radians: Float) -> simd_float4x4 {
        return simd_float4x4(
            simd_float4(cos(radians),   sin(radians),   0,              0),
            simd_float4(-sin(radians),  cos(radians),   0,              0),
            simd_float4(0,              0,              1,              0),
            simd_float4(0,              0,              0,              1)
        )
    }

    static func rotationTransform(_ radians: simd_float3) -> simd_float4x4 {
        return rotationTransformX(radians.x) * rotationTransformY(radians.y) * rotationTransformZ(radians.z)
    }
}

extension simd_float3 {
    var length: Float {
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
    }

    var lengthSquared: Float {
        return self.x * self.x + self.y * self.y + self.z * self.z
    }
}

func thetaRadians(_ vector1: simd_float3, _ vector2: simd_float3) -> Float {
    let dotProduct = dot(normalize(vector1), normalize(vector2))
    return acos(dotProduct)
}

func translateTransform(_ x: Float, _ y: Float, _ z: Float) -> float4x4 {
    var tf = matrix_identity_float4x4
    tf.columns.3 = SIMD4<Float>(x: x, y: y, z: z, w: 1)
    return tf
}

func projection(of vector: simd_float3, using planeNormalVector: simd_float3) -> simd_float3 {
    // u = vector we want to find
    // n = projection of vector onto planeNormalVector (i.e., a scaled planeNormalVector)
    // k = vector
    // strategy:
    // * we know k; we know planeNormalVector; so, we can find n
    // * we know u + n = k; we want to find u; so, we know u = k - n
    let n = projection(of: vector, onto: planeNormalVector)
    return vector - n
}

private func projection(of vector: simd_float3, onto planeNormalVector: simd_float3) -> simd_float3 {
    let dotProduct = dot(vector, planeNormalVector)
    let scale = dotProduct / planeNormalVector.lengthSquared
    return scale * planeNormalVector
}

// angle between 2 planes formed by plane1: vector1 * vector3 and plane2: vector2 * vector3
func angle(between vector1: simd_float3, and vector2: simd_float3, along vector3: simd_float3) -> Float {
    let n = simd_cross(vector1, vector3)
    let nPrime = simd_cross(vector2, vector3)
    let angle = thetaRadians(n, nPrime)

    let n2 = simd_cross(vector2, vector1)
    let dotn2v3 = dot(n2, vector3)
    let angleOffset = dotn2v3 > 0.0 ? -angle : angle

    return angleOffset
}

// get shortest vector along line created by adjacentUnitVector
func oppositeVector(hypotenuseVector: simd_float3, adjacentUnitVector: simd_float3) -> simd_float3 {
    let adjacentLength = dot(hypotenuseVector, adjacentUnitVector)
    let adjacentVector = adjacentLength * adjacentUnitVector
    let oppositeVector = hypotenuseVector - adjacentVector

    return oppositeVector
}
