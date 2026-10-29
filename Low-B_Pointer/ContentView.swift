//
//  ContentView.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isTrackingActive: Bool = false
    @State private var selectedClickModeIndex: Int = 0
    @State private var selectedCamera: String = "MacBook Pro 相機"
    @State private var mirrorCamera: Bool = true
    @State private var smoothingFactor: Double = 0.65
    @State private var activeZonePadding: Double = 0.15
    @State private var pinchThreshold: Double = 0.28
    @State private var dwellDuration: Double = 0.8
    @State private var enableScroll: Bool = true
    @State private var enableRightClick: Bool = true
    @State private var soundFeedback: Bool = false
    @State private var showComingSoonAlert: Bool = false
    
    private let clickModes = ["食指移動 + 中指點擊", "停留懸停點擊", "防位移捏合點擊", "雙指捏合"]
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
             
            demoNoticeBanner
             
            HSplitView {
                cameraSection
                    .frame(minWidth: 500, minHeight: 480)
                 
                controlSection
                    .frame(minWidth: 320, maxWidth: 400)
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .alert("功能開發中", isPresented: $showComingSoonAlert) {
            Button("確定", role: .cancel) { }
        } message: {
            Text("此版本為UI原型，實際手勢辨識與滑鼠控制模組正在研發中，敬請期待！")
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
                HStack(spacing: 6) {
                    Text("手勢鼠標控制")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("預覽版")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                Text("功能開發中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
             
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                Text("DEMO 模式")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Main Toggle Button (Triggers Coming Soon Alert)
            Button {
                showComingSoonAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                    Text("功能開發中 (無法啟動)")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
     
    private var demoNoticeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("此介面為公開展示版本")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("所有底層 Vision 影像追蹤、輔助功能鼠標控制與相機模組均已關閉。此頁面僅供 UI/UX 概念預覽。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button("了解更多") {
                showComingSoonAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.08))
    }
     
    private var cameraSection: some View {
        ZStack {
            Color.black
             
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: 420, height: 300)
                    
                    VStack(spacing: 14) {
                        Image(systemName: "video.badge.waveform")
                            .font(.system(size: 54))
                            .foregroundStyle(
                                LinearGradient(colors: [.secondary, .gray], startPoint: .top, endPoint: .bottom)
                            )
                        
                        Text("相機與手勢辨識模組開發中")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("正式版本將在此區域呈現即時骨骼節點與 Pinch 手勢追蹤預覽")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }
            }
             
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("預覽展示手勢: 就緒")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("辨識模組:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("離線測試中")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                .padding(14)
            }
        }
    }
     
    private var controlSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                trackingStatusCard
                clickModeSection
                cameraPickerSection
                parameterSettingsSection
                gestureTogglesSection
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
     
    
    private var trackingStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                Text("手勢引擎 (開發中)")
                    .font(.headline)
                Spacer()
            }
            
            Text("核心演算法尚未開放調用。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var clickModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("點擊觸發方式")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Picker("點擊模式", selection: $selectedClickModeIndex) {
                ForEach(0..<clickModes.count, id: \.self) { index in
                    Text(clickModes[index]).tag(index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
             
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
            
            Picker("選擇相機", selection: $selectedCamera) {
                Text("MacBook Pro 相機").tag("MacBook Pro 相機")
                Text("外接 4K 超廣角相機 ").tag("外接 4K 超廣角相機")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            
            Toggle("水平鏡像畫面", isOn: $mirrorCamera)
                .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var parameterSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("靈敏度與平滑調整")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("功能開發中")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("指針平滑度")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", smoothingFactor * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $smoothingFactor, in: 0.1...0.95, step: 0.05)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("手勢感應邊界 (滿屏範圍)")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.0f%%", (1.0 - activeZonePadding * 2) * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $activeZonePadding, in: 0.05...0.30, step: 0.02)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("捏合點擊距離閾值")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", pinchThreshold))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $pinchThreshold, in: 0.15...0.45, step: 0.02)
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(10)
    }
    
    private var gestureTogglesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("手勢功能開關")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Toggle("啟用雙指滾動頁面 (開發中)", isOn: $enableScroll)
                .font(.caption)
            Toggle("啟用中指捏合右鍵點擊 (開發中)", isOn: $enableRightClick)
                .font(.caption)
            Toggle("點擊時發出提示音 (開發中)", isOn: $soundFeedback)
                .font(.caption)
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
