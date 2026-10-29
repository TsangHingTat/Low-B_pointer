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
    @Published var thumbToMiddleDistance: CGFloat = 1.0
    @Published var thumbToRingDistance: CGFloat = 1.0
    @Published var fps: Int = 0
    @Published var statusMessage: String = "準備就緒"
     
    @Published var clickMode: ClickMode = .fingerSplit {
        didSet {
            resetGestureStates()
        }
    }
    @Published var dwellDuration: Double = 0.8
    @Published var dwellProgress: Double = 0.0
    @Published var isPinchLocked: Bool = false
    @Published var isMiddleFingerActive: Bool = false
    @Published var isRingFingerActive: Bool = false
    
    @Published var smoothingFactor: Double = 0.65 {
        didSet {
            mouseController.smoothing = smoothingFactor
        }
    }
    @Published var activeZonePadding: Double = 0.15 {
        didSet {
            mouseController.activeZonePadding = CGFloat(activeZonePadding)
        }
    }
    @Published var pinchThreshold: Double = 0.26 {
        didSet {
            detector.pinchDownThreshold = CGFloat(pinchThreshold)
            detector.pinchUpThreshold = CGFloat(pinchThreshold) + 0.10
        }
    }
    @Published var enableRightClick: Bool = true
    @Published var enableScroll: Bool = true
    @Published var soundFeedback: Bool = true
    @Published var mirrorCamera: Bool = true
    
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCameraID: String = "" {
        didSet {
            if !selectedCameraID.isEmpty && selectedCameraID != oldValue {
                cameraManager.selectDevice(withID: selectedCameraID)
            }
        }
    }
     
    private let cameraManager = CameraManager()
    private let detector = HandPoseDetector()
    private let mouseController = MouseController.shared
     
    private var isPinchingLeft: Bool = false
    private var lastRightClickTime: TimeInterval = 0
    private var lastScrollIndexY: CGFloat?
    private var frameCount: Int = 0
    private var lastFpsUpdateTime: TimeInterval = ProcessInfo.processInfo.systemUptime
     
    private var dwellAnchorScreenPoint: CGPoint?
    private var dwellStartTime: TimeInterval?
    private var lastDwellClickTime: TimeInterval = 0
    private let dwellToleranceRadius: CGFloat = 30.0
    private let dwellCooldown: TimeInterval = 0.6
     
    private var lockedPinchScreenPoint: CGPoint?
    private let dragDistanceThreshold: CGFloat = 42.0
    private var isDraggingAfterLock: Bool = false
    
    // Middle Tap Internal Tracking
    private var isMiddleTapping: Bool = false
    private var lastMiddleTapTime: TimeInterval = 0
    
    init() {
        cameraManager.delegate = self
        checkPermissions()
        refreshCameras()
    }
    
    func checkPermissions() {
        cameraAuthStatus = CameraManager.checkAuthorization()
        cameraAuthorized = (cameraAuthStatus == .authorized)
        accessibilityAuthorized = MouseController.checkAccessibilityPermission()
        if cameraAuthorized && cameraFrame == nil {
            startCamera()
        }
    }
    
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
    
    func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func requestAccessibilityPermission() {
        MouseController.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.accessibilityAuthorized = MouseController.checkAccessibilityPermission()
        }
    }
    
    func openAccessibilitySettings() {
        MouseController.openAccessibilitySettings()
    }
    
    func refreshCameras() {
        cameraManager.refreshAvailableDevices()
        availableCameras = cameraManager.availableDevices
        if let current = cameraManager.currentDevice {
            selectedCameraID = current.uniqueID
        } else if let first = availableCameras.first {
            selectedCameraID = first.uniqueID
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
        isTrackingActive.toggle()
        if !isTrackingActive {
            mouseController.reset()
            currentGesture = .none
            resetGestureStates()
        }
    }
    
    func resetGestureStates() {
        if isPinchingLeft || isMiddleFingerActive {
            isPinchingLeft = false
            isMiddleFingerActive = false
            mouseController.setLeftButton(down: false)
        }
        isRingFingerActive = false
        dwellProgress = 0.0
        dwellStartTime = nil
        dwellAnchorScreenPoint = nil
        lockedPinchScreenPoint = nil
        isPinchLocked = false
        isDraggingAfterLock = false
        lastScrollIndexY = nil
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
        self.thumbToMiddleDistance = landmarks.thumbToMiddleDistance
        self.thumbToRingDistance = landmarks.thumbToRingDistance
        
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
        
        guard let indexTip = landmarks.indexTip else { return }
        let now = ProcessInfo.processInfo.systemUptime
         
        if enableScroll && landmarks.indexToMiddleDistance < 0.35 &&
            landmarks.thumbToIndexDistance > 0.4 &&
            landmarks.middleTip != nil {
             
            dwellProgress = 0.0
            dwellStartTime = nil
            dwellAnchorScreenPoint = nil
            lockedPinchScreenPoint = nil
            isPinchLocked = false
            
            let currentY = (indexTip.y + (landmarks.middleTip?.y ?? indexTip.y)) / 2.0
            if let lastY = lastScrollIndexY {
                let deltaY = (currentY - lastY) * 100.0
                if abs(deltaY) > 0.4 {
                    mouseController.scroll(deltaY: deltaY)
                    currentGesture = .scroll
                    statusMessage = "雙指滾動頁面"
                }
            }
            lastScrollIndexY = currentY
            return
        } else {
            lastScrollIndexY = nil
        }
         
        let rawScreenPoint = mouseController.mapToScreen(normalizedPoint: indexTip, mirrored: mirrorCamera)
         
        if clickMode != .fingerSplit && enableRightClick &&
            landmarks.thumbToMiddleDistance < CGFloat(pinchThreshold) &&
            landmarks.thumbToIndexDistance > CGFloat(pinchThreshold) * 1.3 {
            
            dwellProgress = 0.0
            dwellStartTime = nil
            dwellAnchorScreenPoint = nil
            
            if now - lastRightClickTime > 0.5 {
                mouseController.moveTo(point: rawScreenPoint)
                mouseController.performRightClick()
                lastRightClickTime = now
                currentGesture = .rightClick
                statusMessage = "右鍵點擊！"
                if soundFeedback { NSSound.beep() }
            }
            return
        }
         
        switch clickMode {
        case .fingerSplit:
            processFingerSplitMode(at: rawScreenPoint, landmarks: landmarks, now: now)
            
        case .dwell:
            processDwellClick(at: rawScreenPoint, now: now)
            
        case .pinchLock:
            processPinchLockClick(at: rawScreenPoint, landmarks: landmarks, now: now)
            
        case .classicPinch:
            processClassicPinchClick(at: rawScreenPoint, landmarks: landmarks, now: now)
        }
    }
    
    // MARK: - Click Mode Processors
    private func processDwellClick(at rawScreenPoint: CGPoint, now: TimeInterval) {
        if now - lastDwellClickTime < dwellCooldown {
            dwellProgress = 0.0
            dwellStartTime = nil
            dwellAnchorScreenPoint = nil
            mouseController.moveTo(point: rawScreenPoint)
            currentGesture = .moving
            statusMessage = "移動滑鼠中"
            return
        }
        
        if let anchor = dwellAnchorScreenPoint {
            let dist = hypot(rawScreenPoint.x - anchor.x, rawScreenPoint.y - anchor.y)
            if dist <= dwellToleranceRadius {
                let elapsed = now - (dwellStartTime ?? now)
                dwellProgress = min(1.0, elapsed / dwellDuration)
                 
                mouseController.moveTo(point: anchor)
                
                if dwellProgress >= 1.0 {
                    mouseController.performLeftClick()
                    lastDwellClickTime = now
                    dwellStartTime = nil
                    dwellAnchorScreenPoint = nil
                    dwellProgress = 0.0
                    currentGesture = .leftClick
                    statusMessage = "停留點擊成功！"
                    if soundFeedback { NSSound.beep() }
                } else {
                    currentGesture = .dwelling
                    statusMessage = String(format: "停留點擊倒數中... %.0f%%", dwellProgress * 100)
                }
            } else {
                dwellAnchorScreenPoint = rawScreenPoint
                dwellStartTime = now
                dwellProgress = 0.0
                mouseController.moveTo(point: rawScreenPoint)
                currentGesture = .moving
                statusMessage = "移動滑鼠中"
            }
        } else {
            dwellAnchorScreenPoint = rawScreenPoint
            dwellStartTime = now
            dwellProgress = 0.0
            mouseController.moveTo(point: rawScreenPoint)
            currentGesture = .moving
            statusMessage = "移動滑鼠中"
        }
    }
     
    private func processPinchLockClick(at rawScreenPoint: CGPoint, landmarks: HandLandmarks, now: TimeInterval) {
        let pinchDown = detector.pinchDownThreshold
        let pinchUp = detector.pinchUpThreshold
        let prePinchThreshold = pinchDown + 0.08
         
        if landmarks.thumbToIndexDistance < prePinchThreshold {
            if lockedPinchScreenPoint == nil && !isDraggingAfterLock {
                lockedPinchScreenPoint = rawScreenPoint
                isPinchLocked = true
            }
        } else if !isPinchingLeft {
            lockedPinchScreenPoint = nil
            isPinchLocked = false
            isDraggingAfterLock = false
        }
         
        if let locked = lockedPinchScreenPoint {
            let distFromLocked = hypot(rawScreenPoint.x - locked.x, rawScreenPoint.y - locked.y)
            if distFromLocked > dragDistanceThreshold {
                isDraggingAfterLock = true
                lockedPinchScreenPoint = nil
                isPinchLocked = false
                mouseController.moveTo(point: rawScreenPoint)
            } else {
                mouseController.moveTo(point: locked)
            }
        } else {
            mouseController.moveTo(point: rawScreenPoint)
            isPinchLocked = false
        }
         
        if !isPinchingLeft {
            if landmarks.thumbToIndexDistance < pinchDown {
                isPinchingLeft = true
                mouseController.setLeftButton(down: true)
                currentGesture = .leftClick
                statusMessage = isPinchLocked ? "左鍵點擊 (指針已鎖定)" : "左鍵按住 / 拖曳中"
                if soundFeedback { NSSound.beep() }
            } else {
                if isPinchLocked {
                    currentGesture = .dwelling
                    statusMessage = "捏合準備 (指針鎖定中)"
                } else {
                    currentGesture = .moving
                    statusMessage = "移動滑鼠中"
                }
            }
        } else {
            if landmarks.thumbToIndexDistance > pinchUp {
                isPinchingLeft = false
                mouseController.setLeftButton(down: false)
                lockedPinchScreenPoint = nil
                isPinchLocked = false
                isDraggingAfterLock = false
                currentGesture = .moving
                statusMessage = "移動滑鼠中"
            } else {
                currentGesture = isDraggingAfterLock ? .leftDown : .leftClick
                statusMessage = isDraggingAfterLock ? "拖曳中..." : "左鍵按住 (鎖定中)"
            }
        }
    }
     
    private func processFingerSplitMode(at rawScreenPoint: CGPoint, landmarks: HandLandmarks, now: TimeInterval) { 
        mouseController.moveTo(point: rawScreenPoint)
         
        let isMiddleCurled = (landmarks.middleRelativeCurl < 0.68) || (landmarks.middleCurlRatio < 0.65)
        let isMiddlePinched = landmarks.thumbToMiddleDistance < detector.pinchDownThreshold
        let middleActive = isMiddleCurled || isMiddlePinched
        
        let isMiddleReleased = (landmarks.middleRelativeCurl > 0.82) && 
                               (landmarks.middleCurlRatio > 0.76) && 
                               (landmarks.thumbToMiddleDistance > detector.pinchUpThreshold)
        
        if !isMiddleFingerActive {
            if middleActive {
                isMiddleFingerActive = true
                mouseController.setLeftButton(down: true)
                currentGesture = .leftClick
                statusMessage = "中指按下左鍵"
                if soundFeedback { NSSound.beep() }
            }
        } else {
            if isMiddleReleased {
                isMiddleFingerActive = false
                mouseController.setLeftButton(down: false)
                currentGesture = .moving
                statusMessage = "移動滑鼠中"
            } else {
                currentGesture = .leftDown
                statusMessage = "中指按住左鍵 (拖曳中)"
            }
        }
         
        let isRingCurled = (landmarks.ringRelativeCurl < 0.68) || (landmarks.ringCurlRatio < 0.65)
        let isRingPinched = landmarks.thumbToRingDistance < detector.pinchDownThreshold
        let ringActive = isRingCurled || isRingPinched
        
        let isRingReleased = (landmarks.ringRelativeCurl > 0.82) && 
                             (landmarks.ringCurlRatio > 0.76) && 
                             (landmarks.thumbToRingDistance > detector.pinchUpThreshold)
        
        if !isRingFingerActive {
            if ringActive && (now - lastRightClickTime > 0.45) {
                isRingFingerActive = true
                lastRightClickTime = now
                mouseController.performRightClick()
                currentGesture = .rightClick
                statusMessage = "無名指觸發右鍵點擊！"
                if soundFeedback { NSSound.beep() }
            }
        } else {
            if isRingReleased {
                isRingFingerActive = false
            }
        }
        
        if !isMiddleFingerActive && !isRingFingerActive {
            if currentGesture != .scroll {
                currentGesture = .moving
                statusMessage = "移動滑鼠中 (食指)"
            }
        }
    }
     
    private func processClassicPinchClick(at rawScreenPoint: CGPoint, landmarks: HandLandmarks, now: TimeInterval) {
        mouseController.moveTo(point: rawScreenPoint)
        
        if !isPinchingLeft {
            if landmarks.thumbToIndexDistance < detector.pinchDownThreshold {
                isPinchingLeft = true
                mouseController.setLeftButton(down: true)
                currentGesture = .leftClick
                statusMessage = "左鍵按住 / 拖曳中"
                if soundFeedback { NSSound.beep() }
            } else {
                currentGesture = .moving
                statusMessage = "移動滑鼠中"
            }
        } else {
            if landmarks.thumbToIndexDistance > detector.pinchUpThreshold {
                isPinchingLeft = false
                mouseController.setLeftButton(down: false)
                currentGesture = .moving
                statusMessage = "移動滑鼠中"
            } else {
                currentGesture = .leftDown
                statusMessage = "左鍵按住 / 拖曳中"
            }
        }
    }
}
