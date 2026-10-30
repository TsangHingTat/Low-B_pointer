//
//  SmoothFilter.swift
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
        // 防止 NaN 或無效座標破壞濾波器狀態導致游標卡死
        guard target.x.isFinite && target.y.isFinite else {
            return prevPosition ?? .zero
        }
        
        guard let prev = prevPosition, prev.x.isFinite && prev.y.isFinite else {
            prevPosition = target
            prevTimestamp = timestamp
            return target
        }
        
        let rawDt = timestamp - prevTimestamp
        let dt = max(rawDt.isFinite ? rawDt : 0.016, 0.001)
        prevTimestamp = timestamp
        
        // Calculate distance per second
        let dx = target.x - prev.x
        let dy = target.y - prev.y
        let distance = hypot(dx, dy)
        guard distance.isFinite else { return prev }
        
        let velocity = distance / CGFloat(dt)
        guard velocity.isFinite else { return prev }
        
        // Dynamic smoothing and normalized against screen resolution 
        let speedFactor = min(max(velocity / 800.0, 0.0), 1.0)
        let dynamicSmoothing = min(max(baseSmoothing * (1.0 - Double(speedFactor) * 0.75), 0.0), 0.98)
        let alpha = CGFloat(1.0 - dynamicSmoothing)
        
        let filteredX = prev.x + alpha * (target.x - prev.x)
        let filteredY = prev.y + alpha * (target.y - prev.y)
        
        guard filteredX.isFinite && filteredY.isFinite else { return prev }
        
        let filteredPoint = CGPoint(x: filteredX, y: filteredY)
        prevPosition = filteredPoint
        return filteredPoint
    }
}

