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
    case moving = "移動滑鼠 (食指)"
    case dwelling = "停留準備點擊..."
    case leftDown = "左鍵按住 / 拖曳 (中指)"
    case leftClick = "左鍵點擊 (中指)"
    case rightClick = "右鍵點擊 (無名指)"
    case scroll = "滾動頁面 (雙指併攏)"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .none: return "hand.raised.slash"
        case .moving: return "cursorarrow.motionlines"
        case .dwelling: return "timer"
        case .leftDown, .leftClick: return "hand.tap.fill"
        case .rightClick: return "contextualmenu.and.cursor"
        case .scroll: return "arrow.up.and.down"
        }
    }
}
 
enum ClickMode: String, CaseIterable, Identifiable {
    case fingerSplit = "中指左鍵 + 無名指右鍵"
    case dwell = "停留懸停點擊 (停頓自動點擊)"
    case pinchLock = "防位移捏合點擊 (捏合時凍結指針)"
    case classicPinch = "傳統捏合點擊"
    
    var id: String { rawValue }
    
    var shortTitle: String {
        switch self {
        case .fingerSplit: return "中指左鍵 / 無名指右鍵"
        case .dwell: return "停留懸停點擊"
        case .pinchLock: return "防位移捏合"
        case .classicPinch: return "傳統捏合"
        }
    }
    
    var description: String {
        switch self {
        case .fingerSplit:
            return "食指伸直專門負責瞄準移動；中指向下彎曲或輕捏觸發左鍵（按住可拖曳）；無名指向下彎曲或輕捏觸發右鍵。食指完全不移動，點擊精準不跑位！"
        case .dwell:
            return "將指針移至目標後停頓（約 0.8 秒）自動觸發點擊。點擊時完全無需手指動作，徹底避免游標位移！"
        case .pinchLock:
            return "手指開始靠近捏合的瞬間，立即將指針座標凍結在原位，即使手指動作稍有晃動也能精確點中目標。"
        case .classicPinch:
            return "拇指與食指指尖碰觸即觸發點擊，適合習慣原始捏合手勢的操作。"
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
    var thumbToMiddleDistance: CGFloat = 1.0
    var thumbToRingDistance: CGFloat = 1.0
    var indexToMiddleDistance: CGFloat = 1.0
     
    var indexCurlRatio: CGFloat {
        guard let iTip = indexTip, let iMCP = indexMCP else { return 1.0 }
        return hypot(iTip.x - iMCP.x, iTip.y - iMCP.y) / max(palmScale, 0.05)
    }
    
    var middleCurlRatio: CGFloat {
        guard let mTip = middleTip, let mMCP = middleMCP else { return 1.0 }
        return hypot(mTip.x - mMCP.x, mTip.y - mMCP.y) / max(palmScale, 0.05)
    }
    
    var ringCurlRatio: CGFloat {
        guard let rTip = ringTip, let rMCP = ringMCP else { return 1.0 }
        return hypot(rTip.x - rMCP.x, rTip.y - rMCP.y) / max(palmScale, 0.05)
    }
     
    var middleRelativeCurl: CGFloat {
        let i = indexCurlRatio
        guard i > 0.05 else { return 1.0 }
        return middleCurlRatio / i
    }
     
    var ringRelativeCurl: CGFloat {
        let i = indexCurlRatio
        guard i > 0.05 else { return 1.0 }
        return ringCurlRatio / i
    }
     
    var middleFingerCurl: CGFloat { middleRelativeCurl }
     
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
