//
//  Geomtry.swift
//  MatchedGeometryEffect
//
//  Created by Jason Jobe on 12/17/22.
//

import Foundation

extension CGPoint: CustomStringConvertible {
    public var description: String {
        "\(Int(x)):\(Int(y))"
    }
    
    static func *(lhs: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * scale, y: lhs.y * scale)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
}

extension CGSize: CustomStringConvertible {
    public var description: String {
        "\(Int(width))x\(Int(height))"
    }
    
    static func *(lhs: Self, scale: CGFloat) -> Self {
        Self.init(width: lhs.width * scale, height: lhs.height * scale)
    }
    
    static func +(lhs: Self, rhs: Self) -> Self {
        Self(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static func -(lhs: Self, rhs: Self) -> Self {
        Self(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }
    
}

extension CGRect {
    static func *(lhs: Self, scale: CGFloat) -> Self {
        Self.init(origin: lhs.origin * scale, size: lhs.size * scale)
    }
}

public func lerp(start: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
    start + (end - start) * t
}

public func lerp(start: CGPoint, end: CGPoint, t: CGFloat) -> CGSize {
    let pt = start + (end - start) * t
    return CGSize(width: pt.x, height: pt.y)
}

public func lerp(start: CGSize, end: CGSize, t: CGFloat) -> CGSize {
    return start + (end - start) * t
}
