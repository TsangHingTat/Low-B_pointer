//
//  HandGestureViewModel.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import Foundation
import SwiftUI
import Combine
import CoreGraphics
import AVFoundation

@MainActor
final class HandGestureViewModel: ObservableObject, CameraManagerDelegate {
    @Published var cameraAuthStatus: AVAuthorizationStatus = .notDetermined
    @Published var cameraAuthorized: Bool = false
    @Published var accessibilityAuthorized: Bool = false
     
    @Published var isTrackingActive: Bool = false
    @Published var currentGesture: GestureType = .none
    @Published var cameraFrame: CGImage?
    @Published var handLandmarks: HandLandmarks?
     
    @Published var thumbToIndexDistance: CGFloat = 1.0
    @Published var fps: Int = 0
    @Published var statusMessage: String = "準備就緒"
     
    @Published var sensitivity: Double = 2.5 {
        didSet {
            mouseController.sensitivity = sensitivity
        }
    }
    @Published var smoothingFactor: Double = 0.60 {
        didSet {
            mouseController.smoothing = smoothingFactor
        }
    }
    @Published var pinchThreshold: Double = 0.15 {
        didSet {
            detector.pinchDownThreshold = CGFloat(pinchThreshold)
            detector.pinchUpThreshold = CGFloat(pinchThreshold) + 0.10
        }
    }
    
    @Published var dragThreshold: Double = 30.0
    
    @Published var soundFeedback: Bool = true
    @Published var mirrorCamera: Bool = true
    @Published var showCameraFeed: Bool = true
    
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraID: String = "" {
        didSet {
            if !selectedCameraID.isEmpty && selectedCameraID != oldValue {
                cameraManager.selectDevice(withID: selectedCameraID)
                update60FPSAvailability()
            }
        }
    }
    
    @Published var enable60FPS: Bool = true {
        didSet {
            cameraManager.setTargetFPS(enable60FPS ? 60 : 30)
            update60FPSAvailability()
        }
    }
    @Published var is60FPSAvailable: Bool = false
    
    var fpsStatusDescription: String {
        if enable60FPS {
            if is60FPSAvailable {
                return "已啟用 60 FPS 高幀率模式，游標追蹤極致流暢。"
            } else {
                return "當前相機硬體上限為 30 FPS（連接外接 60fps 鏡頭或 iPhone 接續互通相機可達 60 FPS）。"
            }
        } else {
            return "已設定為 30 FPS 標準模式。"
        }
    }
    
    @Published var availableDisplays: [DisplayTarget] = []
    @Published var selectedDisplayID: String = "main" {
        didSet {
            mouseController.targetDisplayMode = selectedDisplayID
        }
    }
    
    var selectedDisplayDescription: String {
        if selectedDisplayID == "main" {
            if let main = availableDisplays.first(where: { $0.isMain }) {
                return "目前鎖定主顯示器：\(main.name)"
            }
            return "鎖定系統主顯示器"
        } else if selectedDisplayID == "cursor" {
            return "當前游標在任一螢幕時，手勢將自動控制該螢幕"
        } else if let match = availableDisplays.first(where: { $0.id == selectedDisplayID }) {
            return "已鎖定特定顯示器：\(match.name)"
        }
        return "主顯示器"
    }
     
    private let cameraManager = CameraManager()
    private let detector = HandPoseDetector()
    private let mouseController = MouseController.shared
     
    @Published var isPinchingLeft: Bool = false
    @Published var isActivelyDragging: Bool = false
    private var pinchAnchorScreenPoint: CGPoint?
    
    private var frameCount: Int = 0
    private var lastFpsUpdateTime: TimeInterval = ProcessInfo.processInfo.systemUptime
    
    init() {
        cameraManager.delegate = self
        cameraManager.setTargetFPS(enable60FPS ? 60 : 30)
        mouseController.sensitivity = sensitivity
        mouseController.smoothing = smoothingFactor
        mouseController.targetDisplayMode = selectedDisplayID
        detector.pinchDownThreshold = CGFloat(pinchThreshold)
        detector.pinchUpThreshold = CGFloat(pinchThreshold) + 0.10
        checkPermissions()
        refreshCameras()
        refreshDisplays()
        update60FPSAvailability()
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func checkPermissions() {
        cameraAuthStatus = CameraManager.checkAuthorization()
        cameraAuthorized = (cameraAuthStatus == .authorized)
        accessibilityAuthorized = MouseController.checkAccessibilityPermission()
        if cameraAuthorized && cameraFrame == nil {
            startCamera()
        }
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func requestCameraPermission() {
        let status = CameraManager.checkAuthorization()
        if status == .denied || status == .restricted {
            openCameraSettings()
            return
        }
        CameraManager.requestAuthorization { [weak self] granted in
            guard let self = self else { return }
            self.cameraAuthStatus = CameraManager.checkAuthorization()
            self.cameraAuthorized = granted
            if granted {
                self.refreshCameras()
                self.startCamera()
            }
        }
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func requestAccessibilityPermission() {
        MouseController.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.accessibilityAuthorized = MouseController.checkAccessibilityPermission()
        }
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func openAccessibilitySettings() {
        MouseController.openAccessibilitySettings()
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func refreshCameras() {
        cameraManager.refreshAvailableDevices()
        availableCameras = cameraManager.availableDevices
        if let current = cameraManager.currentDevice {
            selectedCameraID = current.uniqueID
        } else if let first = availableCameras.first {
            selectedCameraID = first.uniqueID
        }
        update60FPSAvailability()
    }
    
    // Statement was written using GPT-OSS 120B. Review the critical logic and security features.
    func update60FPSAvailability() {
        is60FPSAvailable = cameraManager.is60FPSAvailable
    }
    
    func refreshDisplays() {
        availableDisplays = MouseController.getAvailableDisplays()
        if selectedDisplayID != "main" && selectedDisplayID != "cursor" {
            if !availableDisplays.contains(where: { $0.id == selectedDisplayID }) {
                selectedDisplayID = "main"
            }
        }
    }
    
    func startCamera() {
        cameraManager.start()
    }
    
    func stopCamera() {
        cameraManager.stop()
        cameraFrame = nil
        handLandmarks = nil
        mouseController.reset()
        resetGestureStates()
    }
    
    func toggleTracking() {
        checkPermissions()
        refreshDisplays()
        isTrackingActive.toggle()
        if !isTrackingActive {
            mouseController.reset()
            currentGesture = .none
            resetGestureStates()
        }
    }
    
    func resetGestureStates() {
        if isPinchingLeft {
            isPinchingLeft = false
            mouseController.setLeftButton(down: false)
        }
        pinchAnchorScreenPoint = nil
        isActivelyDragging = false
    }
    
    // MARK: - CameraManagerDelegate 
    nonisolated func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer, previewImage: CGImage?) {
        let landmarks = detector.process(pixelBuffer: pixelBuffer)
        
        Task { @MainActor in
            self.cameraFrame = previewImage
            self.processLandmarks(landmarks)
            self.updateFPS()
        }
    }
    
    private func updateFPS() {
        frameCount += 1
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastFpsUpdateTime
        if elapsed >= 1.0 {
            fps = Int(Double(frameCount) / elapsed)
            frameCount = 0
            lastFpsUpdateTime = now
        }
    }
    
    // MARK: - Gesture Processing Logic
    private func processLandmarks(_ landmarks: HandLandmarks?) {
        guard let landmarks = landmarks else {
            self.handLandmarks = nil
            if currentGesture != .none {
                currentGesture = .none
            }
            resetGestureStates()
            return
        }
        
        self.handLandmarks = landmarks
        self.thumbToIndexDistance = landmarks.thumbToIndexDistance
        
        guard isTrackingActive else {
            currentGesture = .none
            statusMessage = "手勢已偵測（尚未啟用滑鼠控制）"
            resetGestureStates()
            return
        }
        
        guard accessibilityAuthorized else {
            statusMessage = "請先授予「輔助功能」權限以控制系統滑鼠"
            currentGesture = .none
            resetGestureStates()
            return
        }
        
 
        guard let palm = landmarks.palmCenter else { return }
        let rawScreenPoint = mouseController.mapToScreen(normalizedPoint: palm, mirrored: mirrorCamera)
        
 
        let pinchDown = detector.pinchDownThreshold
        let pinchUp = detector.pinchUpThreshold
        
        if !isPinchingLeft {
            if landmarks.thumbToIndexDistance < pinchDown {
                isPinchingLeft = true
                isActivelyDragging = false
                pinchAnchorScreenPoint = rawScreenPoint
                
                mouseController.setLeftButton(down: true, at: rawScreenPoint)
                currentGesture = .leftClick
                statusMessage = "黏合點擊 (左鍵)"
                if soundFeedback { NSSound.beep() }
            } else {
                mouseController.moveTo(point: rawScreenPoint)
                currentGesture = .moving
                statusMessage = "手掌移動鼠標"
            }
        } else {
            if landmarks.thumbToIndexDistance > pinchUp {
                isPinchingLeft = false
                
                if !isActivelyDragging, let anchor = pinchAnchorScreenPoint {
                    mouseController.setLeftButton(down: false, at: anchor)
                } else {
                    mouseController.setLeftButton(down: false, at: rawScreenPoint)
                }
                
                pinchAnchorScreenPoint = nil
                isActivelyDragging = false
                currentGesture = .moving
                statusMessage = "手掌移動鼠標"
            } else {
                if isActivelyDragging {
                    mouseController.dragTo(point: rawScreenPoint)
                    currentGesture = .leftDown
                    statusMessage = "黏合拖曳中"
                } else if let anchor = pinchAnchorScreenPoint {
                    let moveDist = hypot(rawScreenPoint.x - anchor.x, rawScreenPoint.y - anchor.y)
                    if moveDist > CGFloat(dragThreshold) {
                        isActivelyDragging = true
                        mouseController.dragTo(point: rawScreenPoint)
                        currentGesture = .leftDown
                        statusMessage = "黏合拖曳中"
                    } else {
                        mouseController.lockAt(point: anchor)
                        currentGesture = .leftClick
                        statusMessage = "黏合點擊 (鎖定防抖)"
                    }
                }
            }
        }
    }
}
