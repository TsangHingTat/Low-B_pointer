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
    
    var activeZonePadding: CGFloat = 0.15
    var smoothing: Double = 0.65 {
        didSet { filter.baseSmoothing = smoothing }
    }
    var scrollSensitivity: CGFloat = 20.0
    
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
    
        let minX = activeZonePadding
        let maxX = 1.0 - activeZonePadding
        let minY = activeZonePadding
        let maxY = 1.0 - activeZonePadding
        
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
        
        if isLeftButtonDown {
            if let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) {
                event.post(tap: .cghidEventTap)
            }
        } else {
            if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
                event.post(tap: .cghidEventTap)
            }
        }
    }
    
    func setLeftButton(down: Bool) {
        guard down != isLeftButtonDown else { return }
        isLeftButtonDown = down
        
        let mouseType: CGEventType = down ? .leftMouseDown : .leftMouseUp
        if let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: lastMousePosition, mouseButton: .left) {
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
    
    func performRightClick() {
        if let downEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: lastMousePosition, mouseButton: .right) {
            downEvent.post(tap: .cghidEventTap)
        }
        usleep(30000) // 30ms
        if let upEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: lastMousePosition, mouseButton: .right) {
            upEvent.post(tap: .cghidEventTap)
        }
    }
    
    func scroll(deltaY: CGFloat) {
        let scrollAmount = Int32(deltaY * scrollSensitivity)
        guard scrollAmount != 0 else { return }
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: scrollAmount, wheel2: 0, wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }
     
    func reset() {
        if isLeftButtonDown {
            setLeftButton(down: false)
        }
        filter.reset()
    }
}
