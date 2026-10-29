//
//  MouseController.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//


import Foundation
import CoreGraphics
 
final class AdaptiveFilter {
    private var prevPosition: CGPoint?
    private var prevTimestamp: TimeInterval = 0
     
    var baseSmoothing: Double = 0.65
    
    func reset() {
        prevPosition = nil
        prevTimestamp = 0
    }
    
    func filter(target: CGPoint, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> CGPoint {
        guard let prev = prevPosition else {
            prevPosition = target
            prevTimestamp = timestamp
            return target
        }
        
        let dt = max(timestamp - prevTimestamp, 0.001)
        prevTimestamp = timestamp
        
        // Calculate distance per second
        let dx = target.x - prev.x
        let dy = target.y - prev.y
        let distance = hypot(dx, dy)
        let velocity = distance / CGFloat(dt)
        
        // Dynamic smoothing and normalized against screen resolution 
        let speedFactor = min(velocity / 800.0, 1.0)
        let dynamicSmoothing = baseSmoothing * (1.0 - Double(speedFactor) * 0.75)
        let alpha = CGFloat(1.0 - dynamicSmoothing)
        
        let filteredX = prev.x + alpha * (target.x - prev.x)
        let filteredY = prev.y + alpha * (target.y - prev.y)
        
        let filteredPoint = CGPoint(x: filteredX, y: filteredY)
        prevPosition = filteredPoint
        return filteredPoint
    }
}
