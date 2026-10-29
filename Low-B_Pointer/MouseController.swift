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

final class MouseController {
    static let shared = MouseController()
    
    private(set) var isLeftButtonDown: Bool = false
    private var lastMousePosition: CGPoint = .zero
    private let filter = AdaptiveFilter()
    
    var sensitivity: Double = 2.5
    var smoothing: Double = 0.60 {
        didSet { filter.baseSmoothing = smoothing }
    }
    
    init() {
        filter.baseSmoothing = smoothing
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
        guard let screen = NSScreen.main else {
            return .zero
        }
        
        let screenRect = screen.frame
        let screenWidth = screenRect.width
        let screenHeight = screenRect.height
        
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
        
        let clampedX = min(max(nx, minX), maxX)
        let clampedY = min(max(ny, minY), maxY)
        
        let remappedX = (clampedX - minX) / (maxX - minX)
        let remappedY = (clampedY - minY) / (maxY - minY)
        
        let targetX = screenRect.origin.x + remappedX * screenWidth
        let targetY = screenRect.origin.y + remappedY * screenHeight
        
        let targetPoint = CGPoint(x: targetX, y: targetY)
        return filter.filter(target: targetPoint)
    }
    
    // MARK: - Mouse Actions
     
    func moveTo(point: CGPoint) {
        lastMousePosition = point
        CGWarpMouseCursorPosition(point)
        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }
     
    func dragTo(point: CGPoint) {
        lastMousePosition = point
        CGWarpMouseCursorPosition(point)
        if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }
     
    func lockAt(point: CGPoint) {
        lastMousePosition = point
        CGWarpMouseCursorPosition(point)
    }
     
    func setLeftButton(down: Bool, at point: CGPoint? = nil) {
        guard down != isLeftButtonDown else { return }
        isLeftButtonDown = down
        
        let targetPoint = point ?? lastMousePosition
        lastMousePosition = targetPoint
        
        let mouseType: CGEventType = down ? .leftMouseDown : .leftMouseUp
        if let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: targetPoint, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }
    
    func performLeftClick() {
        if let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: lastMousePosition, mouseButton: .left) {
            downEvent.post(tap: .cghidEventTap)
        }
        usleep(30000) // 30ms
        if let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: lastMousePosition, mouseButton: .left) {
            upEvent.post(tap: .cghidEventTap)
        }
    }
     
    func reset() {
        if isLeftButtonDown {
            setLeftButton(down: false)
        }
        filter.reset()
    }
}
