//
//  HandGestureModel.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import Foundation
import CoreGraphics
 
enum GestureType: String, CaseIterable, Identifiable {
    case none = "未偵測到手勢"
    case moving = "手掌移動鼠標"
    case leftClick = "黏合點擊 (左鍵)"
    case leftDown = "黏合按住 / 拖曳"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .none: return "hand.raised.slash"
        case .moving: return "hand.point.up.left.fill"
        case .leftClick: return "hand.tap.fill"
        case .leftDown: return "hand.draw.fill"
        }
    }
}
 
struct HandLandmarks {
    var wrist: CGPoint?
    
    // Thumb
    var thumbTip: CGPoint?
    var thumbIP: CGPoint?
    var thumbMP: CGPoint?
    var thumbCMC: CGPoint?
    
    // Index
    var indexTip: CGPoint?
    var indexDIP: CGPoint?
    var indexPIP: CGPoint?
    var indexMCP: CGPoint?
    
    // Middle
    var middleTip: CGPoint?
    var middleDIP: CGPoint?
    var middlePIP: CGPoint?
    var middleMCP: CGPoint?
    
    // Ring
    var ringTip: CGPoint?
    var ringDIP: CGPoint?
    var ringPIP: CGPoint?
    var ringMCP: CGPoint?
    
    // Little / Pinky
    var littleTip: CGPoint?
    var littleDIP: CGPoint?
    var littlePIP: CGPoint?
    var littleMCP: CGPoint?
     
    var confidence: Float = 0.0
     
    var palmScale: CGFloat = 0.25
     
    var thumbToIndexDistance: CGFloat = 1.0
     
 
    var palmCenter: CGPoint? {
        let mcps = [indexMCP, middleMCP, ringMCP].compactMap { $0 }
        let avgMcp: CGPoint?
        if !mcps.isEmpty {
            let sumX = mcps.reduce(0) { $0 + $1.x }
            let sumY = mcps.reduce(0) { $0 + $1.y }
            avgMcp = CGPoint(x: sumX / CGFloat(mcps.count), y: sumY / CGFloat(mcps.count))
        } else {
            avgMcp = middleMCP ?? indexMCP
        }
        
        if let w = wrist, let m = avgMcp {
            return CGPoint(x: (w.x + m.x) * 0.5, y: (w.y + m.y) * 0.5)
        } else if let m = avgMcp {
            return m
        } else if let w = wrist {
            return w
        }
        return nil
    }
     
    var boneSegments: [(CGPoint, CGPoint)] {
        var segments: [(CGPoint, CGPoint)] = []
        
        func addSegment(_ p1: CGPoint?, _ p2: CGPoint?) {
            if let a = p1, let b = p2 {
                segments.append((a, b))
            }
        }
        
        // Thumb
        addSegment(wrist, thumbCMC)
        addSegment(thumbCMC, thumbMP)
        addSegment(thumbMP, thumbIP)
        addSegment(thumbIP, thumbTip)
        
        // Index
        addSegment(wrist, indexMCP)
        addSegment(indexMCP, indexPIP)
        addSegment(indexPIP, indexDIP)
        addSegment(indexDIP, indexTip)
        
        // Middle
        addSegment(wrist, middleMCP)
        addSegment(middleMCP, middlePIP)
        addSegment(middlePIP, middleDIP)
        addSegment(middleDIP, middleTip)
        
        // Ring
        addSegment(wrist, ringMCP)
        addSegment(ringMCP, ringPIP)
        addSegment(ringPIP, ringDIP)
        addSegment(ringDIP, ringTip)
        
        // Little
        addSegment(wrist, littleMCP)
        addSegment(littleMCP, littlePIP)
        addSegment(littlePIP, littleDIP)
        addSegment(littleDIP, littleTip)
        
        // Palm base
        addSegment(indexMCP, middleMCP)
        addSegment(middleMCP, ringMCP)
        addSegment(ringMCP, littleMCP)
        
        return segments
    }
    
    var allKeypoints: [CGPoint] {
        [
            wrist,
            thumbCMC, thumbMP, thumbIP, thumbTip,
            indexMCP, indexPIP, indexDIP, indexTip,
            middleMCP, middlePIP, middleDIP, middleTip,
            ringMCP, ringPIP, ringDIP, ringTip,
            littleMCP, littlePIP, littleDIP, littleTip
        ].compactMap { $0 }
    }
}
