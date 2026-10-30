//
//  MouseController.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

struct DisplayTarget: Identifiable, Hashable {
    let id: String
    let name: String
    let displayID: CGDirectDisplayID?
    let bounds: CGRect
    let isMain: Bool
}

final class MouseController {
    static let shared = MouseController()
    
    private(set) var isLeftButtonDown: Bool = false
    private var lastMousePosition: CGPoint = {
        let ev = CGEvent(source: nil)
        return ev?.location ?? .zero
    }()
    private let filter = AdaptiveFilter()
    
    var sensitivity: Double = 2.5
    var smoothing: Double = 0.60 {
        didSet { filter.baseSmoothing = smoothing }
    }
    
    /// 目標控制螢幕模式: "main" (主顯示器), "cursor" (跟隨游標), 或個別 CGDirectDisplayID 字串
    var targetDisplayMode: String = "main"
    
    private let eventSource: CGEventSource? = {
        let src = CGEventSource(stateID: .combinedSessionState)
        src?.localEventsSuppressionInterval = 0.0
        return src
    }()
    
    init() {
        filter.baseSmoothing = smoothing
    }
    
    // MARK: - Display Management
    
    static func getAvailableDisplays() -> [DisplayTarget] {
        var result: [DisplayTarget] = []
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        guard displayCount > 0 else { return [] }
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        
        for d in displays {
            let isMain = CGDisplayIsMain(d) != 0
            let bounds = CGDisplayBounds(d)
            let screen = NSScreen.screens.first { s in
                (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == d
            }
            let baseName = screen?.localizedName ?? (isMain ? "主顯示器" : "顯示器 \(d)")
            let resText = "\(Int(bounds.width))×\(Int(bounds.height))"
            let fullName = "\(baseName) (\(resText))"
            result.append(DisplayTarget(
                id: String(d),
                name: fullName,
                displayID: d,
                bounds: bounds,
                isMain: isMain
            ))
        }
        return result
    }
    
    private func getTargetDisplayBounds() -> CGRect {
        if targetDisplayMode != "main" && targetDisplayMode != "cursor",
           let dID = CGDirectDisplayID(targetDisplayMode) {
            let bounds = CGDisplayBounds(dID)
            if bounds.width > 0 && bounds.height > 0 {
                return bounds
            }
        }
        
        
        if targetDisplayMode == "cursor" {
            let curLoc = CGEvent(source: nil)?.location ?? .zero
            var displayCount: UInt32 = 0
            CGGetActiveDisplayList(0, nil, &displayCount)
            if displayCount > 0 {
                var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
                CGGetActiveDisplayList(displayCount, &displays, &displayCount)
                for d in displays {
                    let b = CGDisplayBounds(d)
                    if b.contains(curLoc) {
                        return b
                    }
                }
            }
        }
         
        let mainBounds = CGDisplayBounds(CGMainDisplayID())
        if mainBounds.width > 0 && mainBounds.height > 0 {
            return mainBounds
        }
         
        if let primary = NSScreen.screens.first {
            let h = primary.frame.height
            let f = primary.frame
            return CGRect(x: f.origin.x, y: h - (f.origin.y + f.height), width: f.width, height: f.height)
        }
        return CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }
    
    // MARK: - Accessibility Permissions
    static func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Coordinate Translation
    func mapToScreen(normalizedPoint: CGPoint, mirrored: Bool = true) -> CGPoint {
        guard normalizedPoint.x.isFinite && normalizedPoint.y.isFinite else {
            return lastMousePosition
        }
        
        let targetBounds = getTargetDisplayBounds()
        let width = targetBounds.width
        let height = targetBounds.height
        
        guard width > 0 && height > 0 else {
            return lastMousePosition
        }
        
        // Horizontal mirroring
        let nx = mirrored ? (1.0 - normalizedPoint.x) : normalizedPoint.x
        let ny = 1.0 - normalizedPoint.y
        
        // Center-based sensitivity mapping
        let safeSensitivity = max(sensitivity, 0.4)
        let halfSpan = 0.5 / safeSensitivity
        let minX = 0.5 - halfSpan
        let maxX = 0.5 + halfSpan
        let minY = 0.5 - halfSpan
        let maxY = 0.5 + halfSpan
        
        let spanX = max(maxX - minX, 0.001)
        let spanY = max(maxY - minY, 0.001)
        
        let clampedX = min(max(nx, minX), maxX)
        let clampedY = min(max(ny, minY), maxY)
        
        let remappedX = (clampedX - minX) / spanX
        let remappedY = (clampedY - minY) / spanY
        
        // 防邊界/觸角卡死保護：
        // 邊界保留 2pt 邊界，徹底防止游標觸碰右下角觸發 macOS Quick Note（快速備忘錄）熱點觸發器
        // 亦避免在多螢幕拼接邊緣越界穿透至其他未授權區域或被系統夾死
        let margin: CGFloat = 2.0
        let usableW = max(width - margin * 2.0, 1.0)
        let usableH = max(height - margin * 2.0, 1.0)
        
        let targetX = targetBounds.minX + margin + remappedX * usableW
        let targetY = targetBounds.minY + margin + remappedY * usableH
        
        let safeX = min(max(targetX, targetBounds.minX + margin), targetBounds.maxX - margin)
        let safeY = min(max(targetY, targetBounds.minY + margin), targetBounds.maxY - margin)
        
        let targetPoint = CGPoint(x: safeX, y: safeY)
        return filter.filter(target: targetPoint)
    }
    
    // MARK: - Mouse Actions
    
    private func postEvent(type: CGEventType, at point: CGPoint, button: CGMouseButton = .left) {
        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: type, mouseCursorPosition: point, mouseButton: button) else {
            return
        }
        // 為 macOS Sequoia / Sonoma 提供真實時間戳，避免被 WindowServer 判斷為無效事件丟棄
        event.timestamp = mach_absolute_time()
        event.post(tap: .cghidEventTap)
    }
     
    func moveTo(point: CGPoint) {
        guard point.x.isFinite && point.y.isFinite else { return }
        lastMousePosition = point
        
        // 1. 移動游標位置
        CGWarpMouseCursorPosition(point)
        // 2. 立即重連游標與硬體狀態，防止 macOS 事件抑制造成游標卡死
        CGAssociateMouseAndMouseCursorPosition(1)
        // 3. 發送系統移動事件更新懸停狀態與介面回應
        postEvent(type: .mouseMoved, at: point, button: .left)
    }
     
    func dragTo(point: CGPoint) {
        guard point.x.isFinite && point.y.isFinite else { return }
        lastMousePosition = point
        
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
        postEvent(type: .leftMouseDragged, at: point, button: .left)
    }
     
    func lockAt(point: CGPoint) {
        guard point.x.isFinite && point.y.isFinite else { return }
        lastMousePosition = point
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }
     
    func setLeftButton(down: Bool, at point: CGPoint? = nil) {
        guard down != isLeftButtonDown else { return }
        isLeftButtonDown = down
        
        let targetPoint = point ?? lastMousePosition
        guard targetPoint.x.isFinite && targetPoint.y.isFinite else { return }
        lastMousePosition = targetPoint
        
        CGWarpMouseCursorPosition(targetPoint)
        CGAssociateMouseAndMouseCursorPosition(1)
        
        let mouseType: CGEventType = down ? .leftMouseDown : .leftMouseUp
        postEvent(type: mouseType, at: targetPoint, button: .left)
    }
    
    func performLeftClick() {
        guard lastMousePosition.x.isFinite && lastMousePosition.y.isFinite else { return }
        postEvent(type: .leftMouseDown, at: lastMousePosition, button: .left)
        usleep(30000) // 30ms
        postEvent(type: .leftMouseUp, at: lastMousePosition, button: .left)
    }
     
    func reset() {
        if isLeftButtonDown {
            setLeftButton(down: false)
        }
        filter.reset()
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
