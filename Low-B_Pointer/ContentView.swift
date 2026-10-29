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
                        Text(viewModel.cameraAuthStatus == .denied ? "請在 macOS「系統設定 ➔ 隱私權與安全性 ➔ 相機」中開啟本 App 的權限。" : "相機用於實時捕捉手部手勢，影像僅在設備本地進行處理。")
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
                        if viewModel.showCameraFeed {
                            Image(decorative: cgImage, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: size.width, height: size.height)
                                .scaleEffect(x: viewModel.mirrorCamera ? -1 : 1, y: 1)
                        } else {
                            Color.black
                                .frame(width: size.width, height: size.height)
                        }
                         
                        let isMirrored = viewModel.mirrorCamera
                        let pinchThresh = CGFloat(viewModel.pinchThreshold)
                        let sensitivity = CGFloat(viewModel.sensitivity)
                        let landmarks = viewModel.handLandmarks
                        let isPinching = viewModel.isPinchingLeft
                        let isDragging = viewModel.isActivelyDragging
                        
                        Canvas { context, canvasSize in
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
                             
                            let safeSens = max(sensitivity, 0.4)
                            let span = min(1.0, 1.0 / safeSens)
                            let boxW = drawRect.width * span
                            let boxH = drawRect.height * span
                            let activeRect = CGRect(
                                x: drawRect.minX + (drawRect.width - boxW) / 2.0,
                                y: drawRect.minY + (drawRect.height - boxH) / 2.0,
                                width: boxW,
                                height: boxH
                            )
                            context.stroke(
                                Path(roundedRect: activeRect, cornerRadius: 8),
                                with: .color(Color.yellow.opacity(0.4)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            
                            guard let landmarks = landmarks else { return }
                             
                            func mapPt(_ pt: CGPoint) -> CGPoint {
                                let nx = isMirrored ? (1.0 - pt.x) : pt.x
                                let ny = 1.0 - pt.y
                                return CGPoint(
                                    x: drawRect.minX + nx * drawRect.width,
                                    y: drawRect.minY + ny * drawRect.height
                                )
                            }
                             
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
                             
                            for pt in landmarks.allKeypoints {
                                let mapped = mapPt(pt)
                                let circle = Path(ellipseIn: CGRect(x: mapped.x - 3.5, y: mapped.y - 3.5, width: 7, height: 7))
                                context.fill(circle, with: .color(Color.white.opacity(0.85)))
                            }
                             
                            if let thumb = landmarks.thumbTip, let index = landmarks.indexTip {
                                let thumbPt = mapPt(thumb)
                                let indexPt = mapPt(index)
                                
                                var pinchLine = Path()
                                pinchLine.move(to: thumbPt)
                                pinchLine.addLine(to: indexPt)
                                
                                let currentPinching = landmarks.thumbToIndexDistance < pinchThresh || isPinching
                                let lineColor = currentPinching ? Color.green : Color.orange.opacity(0.8)
                                context.stroke(
                                    pinchLine,
                                    with: .color(lineColor),
                                    style: StrokeStyle(lineWidth: currentPinching ? 3.5 : 1.5)
                                )
                                 
                                let thumbCircle = Path(ellipseIn: CGRect(x: thumbPt.x - 6, y: thumbPt.y - 6, width: 12, height: 12))
                                context.fill(thumbCircle, with: .color(currentPinching ? Color.green : Color.orange))
                                 
                                let indexCircle = Path(ellipseIn: CGRect(x: indexPt.x - 6, y: indexPt.y - 6, width: 12, height: 12))
                                context.fill(indexCircle, with: .color(currentPinching ? Color.green : Color.orange))
                            }
                             
                            if let palm = landmarks.palmCenter {
                                let palmPt = mapPt(palm)
                                 
                                let ringColor: Color
                                if isPinching {
                                    ringColor = isDragging ? Color.purple : Color.green
                                } else {
                                    ringColor = Color.blue.opacity(0.85)
                                }
                                
                                let outerRing = Path(ellipseIn: CGRect(x: palmPt.x - 18, y: palmPt.y - 18, width: 36, height: 36))
                                context.stroke(
                                    outerRing,
                                    with: .color(ringColor),
                                    style: StrokeStyle(lineWidth: isPinching ? 3.0 : 2.0)
                                )
                                 
                                var crosshair = Path()
                                crosshair.move(to: CGPoint(x: palmPt.x - 24, y: palmPt.y))
                                crosshair.addLine(to: CGPoint(x: palmPt.x - 12, y: palmPt.y))
                                crosshair.move(to: CGPoint(x: palmPt.x + 12, y: palmPt.y))
                                crosshair.addLine(to: CGPoint(x: palmPt.x + 24, y: palmPt.y))
                                crosshair.move(to: CGPoint(x: palmPt.x - 24, y: palmPt.y))
                                crosshair.addLine(to: CGPoint(x: palmPt.x, y: palmPt.y - 12))
                                crosshair.move(to: CGPoint(x: palmPt.x, y: palmPt.y + 12))
                                crosshair.addLine(to: CGPoint(x: palmPt.x, y: palmPt.y + 24))
                                context.stroke(crosshair, with: .color(Color.white.opacity(0.7)), lineWidth: 1.5)
                                 
                                let centerDot = Path(ellipseIn: CGRect(x: palmPt.x - 6, y: palmPt.y - 6, width: 12, height: 12))
                                context.fill(centerDot, with: .color(isPinching ? ringColor : Color.cyan))
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
             
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.showCameraFeed.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.showCameraFeed ? "video.fill" : "video.slash")
                            Text(viewModel.showCameraFeed ? "隱藏相機畫面" : "顯示相機畫面")
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(14)
                }
                .padding(14)
                
                Spacer()
                HStack(spacing: 12) {
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
                        HStack(spacing: 8) {
                            Text("黏合距離:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(
                                value: max(0.0, min(1.0, Double(viewModel.thumbToIndexDistance))),
                                total: 0.8
                            )
                            .progressViewStyle(.linear)
                            .frame(width: 80)
                            .tint(viewModel.isPinchingLeft ? (viewModel.isActivelyDragging ? .purple : .green) : .orange)
                            
                            Text(String(format: "%.2f", viewModel.thumbToIndexDistance))
                                .font(.caption)
                                .monospacedDigit()
                            
                            if viewModel.isPinchingLeft {
                                Text(viewModel.isActivelyDragging ? "拖曳中" : "點擊鎖定")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((viewModel.isActivelyDragging ? Color.purple : Color.green).opacity(0.3))
                                    .foregroundColor(viewModel.isActivelyDragging ? .purple : .green)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
                .padding(14)
            }
        }
    }
     
    private var controlSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                trackingStatusCard
                 
                cameraPickerSection
                 
                parameterSettingsSection
                 
                feedbackSection
                 
                gestureGuideSection
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
     
    
    private var trackingStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(viewModel.isTrackingActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isTrackingActive ? "滑鼠手勢控制中" : "已暫停控制")
                    .font(.headline)
                Spacer()
            }
            
            Text(viewModel.isTrackingActive
                 ? "以手掌位置移動帶動滑鼠光標，拇指與食指指尖黏合觸發左鍵點擊（具備防誤拖鎖定機制）。"
                 : "點擊上方按鈕或按下快捷鍵即可啟動手勢控制。")
                .font(.caption)
                .foregroundColor(.secondary)
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
            
            Toggle("顯示相機畫面 (關閉時保留手勢線條)", isOn: $viewModel.showCameraFeed)
                .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var parameterSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("靈敏度與防抖調整")
                .font(.subheadline)
                .fontWeight(.semibold)
             
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("鼠標靈敏度 (游標速度)")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.1fx", viewModel.sensitivity))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.sensitivity, in: 0.6...3.0, step: 0.1)
                HStack {
                    Text("低 (大幅移動)").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("預設 (2.5x)").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("高 (微幅輕移)").font(.caption2).foregroundColor(.secondary)
                }
            }
             
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("指針平滑度 (防抖)")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.smoothingFactor * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.smoothingFactor, in: 0.05...0.90, step: 0.05)
                HStack {
                    Text("更敏捷跟手").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("更平滑抗抖").font(.caption2).foregroundColor(.secondary)
                }
            }
             
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("點擊防誤拖死區 (位移門檻)")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f px", viewModel.dragThreshold))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.dragThreshold, in: 10.0...40.0, step: 2.0)
                HStack {
                    Text("敏捷拖曳 (10px)").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("預設 (30px)").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("抗抖防誤拖 (40px)").font(.caption2).foregroundColor(.secondary)
                }
            }
             
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("黏合點擊距離閾值")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.pinchThreshold))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.pinchThreshold, in: 0.15...0.45, step: 0.02)
                HStack {
                    Text("緊密黏合").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("輕碰黏合").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("操作反饋")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Toggle("點擊時發出提示音", isOn: $viewModel.soundFeedback)
                .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var gestureGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("手勢操作指南")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            guideItem(
                icon: "hand.point.up.left.fill",
                title: "手掌移動鼠標",
                description: "以手掌位置平移即可穩定帶動光標，瞄準目標時手指動作不會干擾游標座標。"
            )
            
            guideItem(
                icon: "hand.tap.fill",
                title: "黏合純點擊 (防誤拖)",
                description: "拇指食指指尖黏合後分開，系統會將游標鎖定在原地釋放，徹底防止手抖觸發短拖曳。"
            )
            
            guideItem(
                icon: "hand.draw.fill",
                title: "黏合拖曳 (故意位移)",
                description: "黏合後若手掌移動超過防抖死區，系統會自動平滑切換至拖曳模式，隨意搬動視窗或文件。"
            )
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
