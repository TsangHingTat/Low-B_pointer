//
//  ContentView.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = HandGestureViewModel()
    @State private var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider()
            
            // Permission Alert Banners
            if !viewModel.cameraAuthorized || !viewModel.accessibilityAuthorized {
                permissionBanner
            }
            
            // Main Content Area
            HSplitView {
                // Left side: Camera View & Live Visuals
                cameraSection
                    .frame(minWidth: 500, minHeight: 480)
                
                // Right side: Controls & Settings
                controlSection
                    .frame(minWidth: 320, maxWidth: 400)
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .onAppear {
            viewModel.checkPermissions()
            if viewModel.cameraAuthorized {
                viewModel.startCamera()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkPermissions()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.point.up.braille.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("手勢鼠標控制")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // FPS Counter
            if viewModel.cameraAuthorized {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.fps > 20 ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text("\(viewModel.fps) FPS")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            // Main Toggle Button
            Button {
                viewModel.toggleTracking()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isTrackingActive ? "stop.circle.fill" : "play.circle.fill")
                    Text(viewModel.isTrackingActive ? "暫停控制" : "啟動手勢控制")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isTrackingActive ? .red : .accentColor)
            .keyboardShortcut(.space, modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Permission Banner
    private var permissionBanner: some View {
        VStack(spacing: 8) {
            if !viewModel.cameraAuthorized {
                HStack {
                    Image(systemName: "camera.badge.ellipsis")
                        .foregroundColor(.orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.cameraAuthStatus == .denied ? "相機權限已被拒絕" : "需要相機存取權限")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(viewModel.cameraAuthStatus == .denied ? "請在 macOS「系統設定 ➔ 隱私權與安全性 ➔ 相機」中開啟本 App 的權限。" : "相機用於實時捕捉手指手勢，影像僅在設備本地進行處理。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if viewModel.cameraAuthStatus == .denied {
                        Button("打開系統設定") {
                            viewModel.openCameraSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("請求相機權限") {
                            viewModel.requestCameraPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button("打開系統設定") {
                            viewModel.openCameraSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(8)
            }
            
            if !viewModel.accessibilityAuthorized {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.blue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("需要「輔助功能」權限")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("macOS 需要您在系統設定中允許此 App 移動滑鼠指針與模擬點擊。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("請求權限") {
                        viewModel.requestAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("打開系統設定") {
                        viewModel.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Camera Section with Skeleton Overlay
    private var cameraSection: some View {
        ZStack {
            Color.black
            
            // Video Preview
            if let cgImage = viewModel.cameraFrame {
                GeometryReader { geo in
                    let size = geo.size
                    
                    ZStack {
                        Image(decorative: cgImage, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size.width, height: size.height)
                            .scaleEffect(x: viewModel.mirrorCamera ? -1 : 1, y: 1)
                        
                        // Hand Skeleton and Gesture Overlay Canvas
                        let isMirrored = viewModel.mirrorCamera
                        let pad = CGFloat(viewModel.activeZonePadding)
                        let pinchThresh = CGFloat(viewModel.pinchThreshold)
                        let landmarks = viewModel.handLandmarks
                        
                        Canvas { context, canvasSize in
                            // Compute video fitting rect inside the canvas
                            let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
                            let viewAspect = canvasSize.width / canvasSize.height
                            
                            var drawRect = CGRect.zero
                            if viewAspect > imageAspect {
                                let h = canvasSize.height
                                let w = h * imageAspect
                                drawRect = CGRect(x: (canvasSize.width - w) / 2, y: 0, width: w, height: h)
                            } else {
                                let w = canvasSize.width
                                let h = w / imageAspect
                                drawRect = CGRect(x: 0, y: (canvasSize.height - h) / 2, width: w, height: h)
                            }
                            
                            // Draw Active Tracking Zone Border
                            let activeRect = CGRect(
                                x: drawRect.minX + drawRect.width * pad,
                                y: drawRect.minY + drawRect.height * pad,
                                width: drawRect.width * (1.0 - 2 * pad),
                                height: drawRect.height * (1.0 - 2 * pad)
                            )
                            context.stroke(
                                Path(roundedRect: activeRect, cornerRadius: 8),
                                with: .color(Color.yellow.opacity(0.4)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            
                            guard let landmarks = landmarks else { return }
                            
                            // Convert normalized point to canvas point
                            func mapPt(_ pt: CGPoint) -> CGPoint {
                                let nx = isMirrored ? (1.0 - pt.x) : pt.x
                                let ny = 1.0 - pt.y
                                return CGPoint(
                                    x: drawRect.minX + nx * drawRect.width,
                                    y: drawRect.minY + ny * drawRect.height
                                )
                            }
                            
                            // 1. Draw Bones
                            for (p1, p2) in landmarks.boneSegments {
                                var path = Path()
                                path.move(to: mapPt(p1))
                                path.addLine(to: mapPt(p2))
                                context.stroke(
                                    path,
                                    with: .color(Color.cyan.opacity(0.65)),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                            }
                            
                            // 2. Draw Joints
                            for pt in landmarks.allKeypoints {
                                let mapped = mapPt(pt)
                                let circle = Path(ellipseIn: CGRect(x: mapped.x - 3.5, y: mapped.y - 3.5, width: 7, height: 7))
                                context.fill(circle, with: .color(Color.white.opacity(0.85)))
                            }
                            
                            // 3. Highlight Thumb and Index Pinch line
                            if let thumb = landmarks.thumbTip, let index = landmarks.indexTip {
                                let thumbPt = mapPt(thumb)
                                let indexPt = mapPt(index)
                                
                                var pinchLine = Path()
                                pinchLine.move(to: thumbPt)
                                pinchLine.addLine(to: indexPt)
                                
                                let isPinching = landmarks.thumbToIndexDistance < pinchThresh
                                let lineColor = isPinching ? Color.green : Color.orange.opacity(0.8)
                                context.stroke(
                                    pinchLine,
                                    with: .color(lineColor),
                                    style: StrokeStyle(lineWidth: isPinching ? 3.5 : 1.5)
                                )
                                
                                // Thumb indicator
                                let thumbCircle = Path(ellipseIn: CGRect(x: thumbPt.x - 6, y: thumbPt.y - 6, width: 12, height: 12))
                                context.fill(thumbCircle, with: .color(isPinching ? Color.green : Color.orange))
                            }
                            
                            // 4. Highlight Cursor Tracking Point (Index Tip)
                            if let index = landmarks.indexTip {
                                let indexPt = mapPt(index)
                                
                                // Outer glow circle
                                let glowCircle = Path(ellipseIn: CGRect(x: indexPt.x - 14, y: indexPt.y - 14, width: 28, height: 28))
                                context.stroke(glowCircle, with: .color(Color.green.opacity(0.7)), lineWidth: 2)
                                
                                // Center point
                                let centerDot = Path(ellipseIn: CGRect(x: indexPt.x - 6, y: indexPt.y - 6, width: 12, height: 12))
                                context.fill(centerDot, with: .color(Color.green))
                                
                                // Dwell Progress Ring (Apple Vision Pro style)
                                if viewModel.clickMode == .dwell && viewModel.dwellProgress > 0.05 {
                                    var progressArc = Path()
                                    let radius: CGFloat = 22
                                    let startAngle = Angle(degrees: -90)
                                    let endAngle = Angle(degrees: -90 + 360 * viewModel.dwellProgress)
                                    progressArc.addArc(center: indexPt, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                                    context.stroke(progressArc, with: .color(Color.yellow), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                }
                                
                                // Position Lock Ring Indicator
                                if viewModel.clickMode == .pinchLock && viewModel.isPinchLocked {
                                    let lockRing = Path(ellipseIn: CGRect(x: indexPt.x - 22, y: indexPt.y - 22, width: 44, height: 44))
                                    context.stroke(lockRing, with: .color(Color.cyan), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                                }
                            }
                            
                            // 5. Highlight Middle (Left Click) and Ring (Right Click) in FingerSplit Mode
                            if viewModel.clickMode == .fingerSplit {
                                if let middle = landmarks.middleTip {
                                    let middlePt = mapPt(middle)
                                    let isActive = viewModel.isMiddleFingerActive
                                    let middleCircle = Path(ellipseIn: CGRect(x: middlePt.x - 9, y: middlePt.y - 9, width: 18, height: 18))
                                    context.fill(middleCircle, with: .color(isActive ? Color.blue : Color.blue.opacity(0.35)))
                                    context.stroke(middleCircle, with: .color(Color.white.opacity(0.8)), lineWidth: 1.5)
                                }
                                
                                if let ring = landmarks.ringTip {
                                    let ringPt = mapPt(ring)
                                    let isActive = viewModel.isRingFingerActive
                                    let ringCircle = Path(ellipseIn: CGRect(x: ringPt.x - 9, y: ringPt.y - 9, width: 18, height: 18))
                                    context.fill(ringCircle, with: .color(isActive ? Color.orange : Color.orange.opacity(0.35)))
                                    context.stroke(ringCircle, with: .color(Color.white.opacity(0.8)), lineWidth: 1.5)
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(viewModel.cameraAuthorized ? "正在啟動相機..." : "相機未授權")
                        .foregroundColor(.secondary)
                }
            }
            
            // HUD Overlay at Bottom of Camera View
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    // Current Gesture Pill
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.currentGesture.iconName)
                            .font(.body)
                        Text(viewModel.currentGesture.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    if viewModel.handLandmarks != nil {
                        if viewModel.clickMode == .fingerSplit {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(viewModel.isMiddleFingerActive ? Color.blue : Color.gray.opacity(0.6))
                                        .frame(width: 8, height: 8)
                                    Text("中指左鍵: \(viewModel.isMiddleFingerActive ? "按下" : "就緒")")
                                        .font(.caption2)
                                        .fontWeight(viewModel.isMiddleFingerActive ? .bold : .regular)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.isMiddleFingerActive ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(viewModel.isRingFingerActive ? Color.orange : Color.gray.opacity(0.6))
                                        .frame(width: 8, height: 8)
                                    Text("無名指右鍵: \(viewModel.isRingFingerActive ? "觸發" : "就緒")")
                                        .font(.caption2)
                                        .fontWeight(viewModel.isRingFingerActive ? .bold : .regular)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.isRingFingerActive ? Color.orange.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        } else if viewModel.clickMode == .dwell {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text("停留進度:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ProgressView(value: viewModel.dwellProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .frame(width: 75)
                                    .tint(viewModel.dwellProgress > 0.8 ? .green : .yellow)
                                Text(String(format: "%.0f%%", viewModel.dwellProgress * 100))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        } else {
                            HStack(spacing: 6) {
                                Text("捏合距離:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ProgressView(
                                    value: max(0.0, min(1.0, Double(viewModel.thumbToIndexDistance))),
                                    total: 0.8
                                )
                                .progressViewStyle(.linear)
                                .frame(width: 80)
                                .tint(viewModel.thumbToIndexDistance < CGFloat(viewModel.pinchThreshold) ? .green : .blue)
                                
                                Text(String(format: "%.2f", viewModel.thumbToIndexDistance))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(14)
            }
        }
    }
    
    // MARK: - Control Section
    private var controlSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Tracking Status Card
                trackingStatusCard
                
                // Click Mode Selector
                clickModeSection
                
                // Camera Selector
                cameraPickerSection
                
                // Sensitivity & Smoothing Sliders
                parameterSettingsSection
                
                // Gesture Features Toggles
                gestureTogglesSection
                
                // Visual Guide Card
                gestureGuideSection
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Subviews in Control Section
    
    private var trackingStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(viewModel.isTrackingActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isTrackingActive ? "滑鼠手勢控制中" : "已暫停控制")
                    .font(.headline)
                Spacer()
                Text("⌘ + 空白鍵")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.quaternaryLabelColor))
                    .cornerRadius(4)
            }
            
            Text(statusCardSubtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var statusCardSubtitle: String {
        guard viewModel.isTrackingActive else {
            return "點擊上方按鈕或按下快捷鍵即可啟動手勢控制。"
        }
        switch viewModel.clickMode {
        case .fingerSplit:
            return "【中指左鍵 + 無名指右鍵】食指瞄準移動，中指按壓控制左鍵（按住拖曳），無名指按壓控制右鍵。食指完全不位移。"
        case .dwell:
            return "【停留懸停點擊】移動食指至目標並停留約 \(String(format: "%.1f", viewModel.dwellDuration)) 秒，自動觸發點擊，指針完全不位移。"
        case .pinchLock:
            return "【防位移捏合】食指瞄準目標，雙指靠近時指針立即凍結，捏合完成點擊。"
        case .classicPinch:
            return "【捏合】食指移動光標，拇指食指捏合為左鍵。"
        }
    }
    
    private var clickModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("點擊觸發方式")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(viewModel.clickMode.shortTitle)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
            
            Picker("點擊模式", selection: $viewModel.clickMode) {
                ForEach(ClickMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Text(viewModel.clickMode.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            
            if viewModel.clickMode == .dwell {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("停留觸發時間")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.1f 秒", viewModel.dwellDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.dwellDuration, in: 0.4...1.6, step: 0.1)
                    HStack {
                        Text("敏捷快速 (0.4s)").font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("充裕防誤觸 (1.6s)").font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var cameraPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相機設備")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Picker("選擇相機", selection: $viewModel.selectedCameraID) {
                ForEach(viewModel.availableCameras, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Toggle("水平鏡像畫面", isOn: $viewModel.mirrorCamera)
                .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var parameterSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("靈敏度與平滑調整")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Smoothing Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("指針平滑度")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.smoothingFactor * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.smoothingFactor, in: 0.1...0.95, step: 0.05)
                HStack {
                    Text("更靈敏").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("更穩定防抖").font(.caption2).foregroundColor(.secondary)
                }
            }
            
            // Active Zone (Reachability) Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("手勢感應邊界 (滿屏範圍)")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", (1.0 - viewModel.activeZonePadding * 2) * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.activeZonePadding, in: 0.05...0.30, step: 0.02)
                HStack {
                    Text("大幅移動").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("小幅輕移").font(.caption2).foregroundColor(.secondary)
                }
            }
            
            // Pinch Threshold Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("捏合點擊距離閾值")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.pinchThreshold))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.pinchThreshold, in: 0.15...0.45, step: 0.02)
                HStack {
                    Text("緊密捏合").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("輕輕靠近").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var gestureTogglesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("手勢功能開關")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Toggle("啟用雙指滾動頁面", isOn: $viewModel.enableScroll)
                .font(.caption)
            Toggle("啟用中指捏合右鍵點擊", isOn: $viewModel.enableRightClick)
                .font(.caption)
            Toggle("點擊時發出提示音", isOn: $viewModel.soundFeedback)
                .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var gestureGuideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("手勢操作指南")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            guideItem(icon: "hand.point.up.fill", title: "移動鼠標 (食指)", description: "舉起食指在鏡頭中移動即可帶動光標，食指完全不負責按鍵，瞄準極致穩定。")
            
            switch viewModel.clickMode {
            case .fingerSplit:
                guideItem(icon: "hand.raised.fingers.spread.fill", title: "中指左鍵 + 無名指右鍵 (當前模式)", description: "中指下彎/輕捏為左鍵（按住可拖曳）；無名指下彎/輕捏為右鍵。食指零位移！")
            case .dwell:
                guideItem(icon: "timer", title: "停留點擊 (當前模式)", description: "食指移至目標後停頓 \(String(format: "%.1f", viewModel.dwellDuration)) 秒自動觸發點擊，指針絕對不位移。")
            case .pinchLock:
                guideItem(icon: "lock.shield.fill", title: "防位移捏合 (當前模式)", description: "手指開始靠近時游標自動鎖定在原位，捏合觸發點擊，大幅移動才拖曳。")
            case .classicPinch:
                guideItem(icon: "hand.tap.fill", title: "傳統捏合 (當前模式)", description: "拇指與食指指尖碰觸即點擊。持續捏合移動可拖曳。")
            }
            
            if viewModel.clickMode != .fingerSplit {
                guideItem(icon: "contextualmenu.and.cursor", title: "右鍵單擊", description: "拇指與中指輕觸捏合，觸發右鍵選單。")
            }
            guideItem(icon: "arrow.up.and.down.circle.fill", title: "雙指滾動", description: "食指與中指併攏同時上下移動，快速滾動頁面。")
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private func guideItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ContentView()
}
