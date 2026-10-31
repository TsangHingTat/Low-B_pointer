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
            headerBar
            Divider()
            
            if !viewModel.cameraAuthorized || !viewModel.accessibilityAuthorized {
                permissionBanner
            }
            
            HSplitView {
                cameraSection
                    .frame(minWidth: 350, minHeight: 480)
                controlSection
                    .frame(minWidth: 320, maxWidth: 400)
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .onAppear {
            viewModel.checkPermissions()
            if viewModel.cameraAuthorized { viewModel.startCamera() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkPermissions()
            viewModel.refreshDisplays()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            viewModel.refreshDisplays()
        }
        .onDisappear { viewModel.stopCamera() }
    }
    
    private var headerBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.point.up.braille.fill")
                .font(.system(size: 24))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("手勢鼠標控制")
                    .font(.headline).fontWeight(.bold)
                Text(viewModel.statusMessage)
                    .font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if viewModel.cameraAuthorized {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.fps > 45 ? Color.cyan : (viewModel.fps > 20 ? Color.green : Color.orange))
                        .frame(width: 8, height: 8)
                    Text("\(viewModel.fps) FPS\(viewModel.fps > 45 ? " (60Hz)" : "")")
                        .font(.caption).monospacedDigit()
                        .foregroundColor(viewModel.fps > 45 ? .primary : .secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            Button {
                viewModel.toggleTracking()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isTrackingActive ? "stop.circle.fill" : "play.circle.fill")
                    Text(viewModel.isTrackingActive ? "暫停控制" : "啟動手勢控制")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isTrackingActive ? .red : .accentColor)
            .keyboardShortcut(.space, modifiers: [.command])
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var permissionBanner: some View {
        VStack(spacing: 8) {
            if !viewModel.cameraAuthorized {
                HStack {
                    Image(systemName: "camera.badge.ellipsis")
                        .foregroundColor(.orange).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.cameraAuthStatus == .denied ? "相機權限已被拒絕" : "需要相機存取權限")
                            .font(.subheadline).fontWeight(.semibold)
                        Text(viewModel.cameraAuthStatus == .denied ?
                             "請在 macOS「系統設定 ➔ 隱私權與安全性 ➔ 相機」中開啟本 App 的權限。" :
                             "相機用於實時捕捉手部手勢，影像僅在設備本地進行處理。")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if viewModel.cameraAuthStatus == .denied {
                        Button("打開系統設定") { viewModel.openCameraSettings() }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                    } else {
                        Button("請求相機權限") { viewModel.requestCameraPermission() }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                        Button("打開系統設定") { viewModel.openCameraSettings() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(10).background(Color.orange.opacity(0.12)).cornerRadius(8)
            }
            
            if !viewModel.accessibilityAuthorized {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.blue).font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("需要「輔助功能」權限")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("macOS 需要您在系統設定中允許此 App 移動滑鼠指針與模擬點擊。")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("請求權限") { viewModel.requestAccessibilityPermission() }
                        .buttonStyle(.bordered).controlSize(.small)
                    Button("打開系統設定") { viewModel.openAccessibilitySettings() }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
                .padding(10).background(Color.blue.opacity(0.12)).cornerRadius(8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var cameraSection: some View {
        ZStack {
            Color.black
            
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
                        }
                        
                        let isMirrored = viewModel.mirrorCamera
                        let pinchThresh = CGFloat(viewModel.pinchThreshold)
                        let sensitivity = CGFloat(viewModel.sensitivity)
                        let landmarks = viewModel.handLandmarks
                        let isPinching = viewModel.isPinchingLeft
                        let isDragging = viewModel.isActivelyDragging
                        
                        Canvas { ctx, sz in
                            let imgAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
                            let viewAspect = sz.width / sz.height
                            var drawRect = CGRect.zero
                            if viewAspect > imgAspect {
                                let h = sz.height
                                let w = h * imgAspect
                                drawRect = CGRect(x: (sz.width - w) / 2, y: 0, width: w, height: h)
                            } else {
                                let w = sz.width
                                let h = w / imgAspect
                                drawRect = CGRect(x: 0, y: (sz.height - h) / 2, width: w, height: h)
                            }
                            
                            let safeSens = max(sensitivity, 0.4)
                            let span = min(1.0, 1.0 / safeSens)
                            let boxW = drawRect.width * span
                            let boxH = drawRect.height * span
                            let activeRect = CGRect(
                                x: drawRect.minX + (drawRect.width - boxW) / 2,
                                y: drawRect.minY + (drawRect.height - boxH) / 2,
                                width: boxW,
                                height: boxH
                            )
                            ctx.stroke(
                                Path(roundedRect: activeRect, cornerRadius: 8),
                                with: .color(Color.yellow.opacity(0.4)),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6,4])
                            )
                            
                            guard let l = landmarks else { return }
                            
                            func map(_ p: CGPoint) -> CGPoint {
                                let nx = isMirrored ? (1.0 - p.x) : p.x
                                let ny = 1.0 - p.y
                                return CGPoint(
                                    x: drawRect.minX + nx * drawRect.width,
                                    y: drawRect.minY + ny * drawRect.height
                                )
                            }
                            
                            for (a,b) in l.boneSegments {
                                var p = Path()
                                p.move(to: map(a)); p.addLine(to: map(b))
                                ctx.stroke(p, with: .color(Color.cyan.opacity(0.65)),
                                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            }
                            
                            for pt in l.allKeypoints {
                                let m = map(pt)
                                let circ = Path(ellipseIn: CGRect(x: m.x-3.5, y: m.y-3.5, width: 7, height: 7))
                                ctx.fill(circ, with: .color(Color.white.opacity(0.85)))
                            }
                            
                            if let thumb = l.thumbTip, let index = l.indexTip {
                                let t = map(thumb), i = map(index)
                                var line = Path(); line.move(to: t); line.addLine(to: i)
                                let currPinch = l.thumbToIndexDistance < pinchThresh || isPinching
                                ctx.stroke(line,
                                           with: .color(currPinch ? Color.green : Color.orange.opacity(0.8)),
                                           style: StrokeStyle(lineWidth: currPinch ? 3.5 : 1.5))
                                
                                let tC = Path(ellipseIn: CGRect(x: t.x-6, y: t.y-6, width: 12, height: 12))
                                ctx.fill(tC, with: .color(currPinch ? Color.green : Color.orange))
                                let iC = Path(ellipseIn: CGRect(x: i.x-6, y: i.y-6, width: 12, height: 12))
                                ctx.fill(iC, with: .color(currPinch ? Color.green : Color.orange))
                            }
                            
                            if let palm = l.palmCenter {
                                let p = map(palm)
                                let ringColor: Color = isPinching ? (isDragging ? Color.purple : Color.green) : Color.blue.opacity(0.85)
                                let outer = Path(ellipseIn: CGRect(x: p.x-18, y: p.y-18, width: 36, height: 36))
                                ctx.stroke(outer, with: .color(ringColor),
                                           style: StrokeStyle(lineWidth: isPinching ? 3.0 : 2.0))
                                
                                var cross = Path()
                                cross.move(to: CGPoint(x: p.x-24, y: p.y))
                                cross.addLine(to: CGPoint(x: p.x-12, y: p.y))
                                cross.move(to: CGPoint(x: p.x+12, y: p.y))
                                cross.addLine(to: CGPoint(x: p.x+24, y: p.y))
                                cross.move(to: CGPoint(x: p.x-24, y: p.y))
                                cross.addLine(to: CGPoint(x: p.x, y: p.y-12))
                                cross.move(to: CGPoint(x: p.x, y: p.y+12))
                                cross.addLine(to: CGPoint(x: p.x, y: p.y+24))
                                ctx.stroke(cross, with: .color(Color.white.opacity(0.7)), lineWidth: 1.5)
                                
                                let dot = Path(ellipseIn: CGRect(x: p.x-6, y: p.y-6, width: 12, height: 12))
                                ctx.fill(dot, with: .color(isPinching ? ringColor : Color.cyan))
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
                    Button {
                        viewModel.showCameraFeed.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.showCameraFeed ? "video.fill" : "video.slash")
                            Text(viewModel.showCameraFeed ? "隱藏相機畫面" : "顯示相機畫面")
                        }
                        .font(.caption).foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial).cornerRadius(14)
                }
                .padding(14)
                
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.currentGesture.iconName).font(.body)
                        Text(viewModel.currentGesture.rawValue).font(.subheadline).fontWeight(.medium)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial).cornerRadius(20)
                    
                    Spacer()
                    
                    if viewModel.handLandmarks != nil {
                        HStack(spacing: 8) {
                            Text("黏合距離:").font(.caption).foregroundColor(.secondary)
                            
                            ProgressView(
                                value: max(0.0, min(1.0, Double(viewModel.thumbToIndexDistance))),
                                total: 0.8
                            )
                            .progressViewStyle(.linear).frame(width: 80)
                            .tint(viewModel.isPinchingLeft ? (viewModel.isActivelyDragging ? .purple : .green) : .orange)
                            
                            Text(String(format: "%.2f", viewModel.thumbToIndexDistance))
                                .font(.caption).monospacedDigit()
                            
                            if viewModel.isPinchingLeft {
                                Text(viewModel.isActivelyDragging ? "拖曳中" : "點擊鎖定")
                                    .font(.caption2).fontWeight(.bold)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background((viewModel.isActivelyDragging ? Color.purple : Color.green).opacity(0.3))
                                    .foregroundColor(viewModel.isActivelyDragging ? .purple : .green)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial).cornerRadius(16)
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
                displayPickerSection
                parameterSettingsSection
                feedbackSection
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var trackingStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(viewModel.isTrackingActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(viewModel.isTrackingActive ? "滑鼠手勢控制中" : "已暫停控制")
                    .font(.headline)
                Spacer()
            }
            Text(viewModel.isTrackingActive ?
                 "以手掌位置移動帶動滑鼠光標，拇指與食指指尖黏合觸發左鍵點擊（具備防誤拖鎖定機制）。" :
                 "點擊上方按鈕或按下快捷鍵即可啟動手勢控制。")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(12).background(Color(NSColor.textBackgroundColor)).cornerRadius(10)
    }
    
    private var cameraPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相機設備").font(.subheadline).fontWeight(.semibold)
            Picker("選擇相機", selection: $viewModel.selectedCameraID) {
                ForEach(viewModel.availableCameras, id: \.uniqueID) {
                    Text($0.localizedName).tag($0.uniqueID)
                }
            }
            .pickerStyle(.menu).labelsHidden()
            Toggle("水平鏡像畫面", isOn: $viewModel.mirrorCamera).font(.caption)
            Toggle("顯示相機畫面", isOn: $viewModel.showCameraFeed).font(.caption)
            
            Divider().padding(.vertical, 2)
            
            Toggle("啟用 60 FPS 高幀率模式", isOn: $viewModel.enable60FPS).font(.caption)
            
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: viewModel.is60FPSAvailable ? "bolt.fill" : "info.circle")
                    .foregroundColor(viewModel.is60FPSAvailable ? .green : .secondary)
                    .font(.caption2)
                    .padding(.top, 1)
                Text(viewModel.fpsStatusDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).background(Color(NSColor.textBackgroundColor)).cornerRadius(10)
    }
    
    private var displayPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("控制顯示器").font(.subheadline).fontWeight(.semibold)
            Picker("選擇顯示器", selection: $viewModel.selectedDisplayID) {
                Text("主顯示器 (預設)").tag("main")
                if viewModel.availableDisplays.count > 1 {
                    Text("跟隨游標所在螢幕").tag("cursor")
                    Divider()
                    ForEach(viewModel.availableDisplays) { display in
                        Text(display.name).tag(display.id)
                    }
                }
            }
            .pickerStyle(.menu).labelsHidden()
            
            Text(viewModel.selectedDisplayDescription)
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(12).background(Color(NSColor.textBackgroundColor)).cornerRadius(10)
    }
    
    private var parameterSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("靈敏度與防抖調整")
                .font(.subheadline).fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("鼠標靈敏度 (游標速度)").font(.caption)
                    Spacer()
                    Text(String(format: "%.1fx", viewModel.sensitivity))
                        .font(.caption).foregroundColor(.secondary)
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
                    Text("指針平滑度 (防抖)").font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.smoothingFactor * 100))
                        .font(.caption).foregroundColor(.secondary)
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
                    Text("點擊防誤拖死區 (位移門檻)").font(.caption)
                    Spacer()
                    Text(String(format: "%.0f px", viewModel.dragThreshold))
                        .font(.caption).foregroundColor(.secondary)
                }
                Slider(value: $viewModel.dragThreshold, in: 10...40, step: 2)
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
                    Text("黏合點擊距離閾值").font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.pinchThreshold))
                        .font(.caption).foregroundColor(.secondary)
                }
                Slider(value: $viewModel.pinchThreshold, in: 0.15...0.45, step: 0.02)
                HStack {
                    Text("緊密黏合").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("輕碰黏合").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(12).background(Color(NSColor.textBackgroundColor)).cornerRadius(10)
    }
    
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("操作反饋")
                .font(.subheadline).fontWeight(.semibold)
            Toggle("點擊時發出提示音", isOn: $viewModel.soundFeedback).font(.caption)
        }
        .padding(12).background(Color(NSColor.textBackgroundColor)).cornerRadius(10)
    }

}

#Preview {
    ContentView()
}
