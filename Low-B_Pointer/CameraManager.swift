//
//  CameraManager.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage
import VideoToolbox

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer, previewImage: CGImage?)
}

final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.handgesturecontrol.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.handgesturecontrol.videoOutputQueue", qos: .userInteractive)
    
    private var currentInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    
    private var isSessionConfigured: Bool = false
    
    weak var delegate: CameraManagerDelegate?
    
    private(set) var availableDevices: [AVCaptureDevice] = []
    private(set) var currentDevice: AVCaptureDevice?
    private(set) var targetFPS: Int = 60
    
    var is60FPSAvailable: Bool {
        guard let device = currentDevice else { return false }
        return device.formats.contains { format in
            format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 59.9 }
        }
    }
    
    override init() {
        super.init()
        refreshAvailableDevices()
    }
    
    func refreshAvailableDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .external
            ],
            mediaType: .video,
            position: .unspecified
        )
        availableDevices = discoverySession.devices
        if currentDevice == nil {
            currentDevice = discoverySession.devices.first
        }
    }
    
    static func checkAuthorization() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func selectDevice(withID deviceID: String) {
        guard let device = availableDevices.first(where: { $0.uniqueID == deviceID }) else { return }
        currentDevice = device
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isSessionConfigured else {
                // If not configured yet, currentDevice is set and will be added during configureSession()
                return
            }
            
            self.captureSession.beginConfiguration()
            if let current = self.currentInput {
                self.captureSession.removeInput(current)
                self.currentInput = nil
            }
            if let newInput = try? AVCaptureDeviceInput(device: device),
               self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.currentInput = newInput
                self.applyFrameRate(to: device, targetFPS: self.targetFPS)
            }
            self.captureSession.commitConfiguration()
        }
    }
    
    func setTargetFPS(_ fps: Int) {
        targetFPS = fps
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.currentDevice else { return }
            self.captureSession.beginConfiguration()
            self.applyFrameRate(to: device, targetFPS: fps)
            self.captureSession.commitConfiguration()
        }
    }
    
    private func applyFrameRate(to device: AVCaptureDevice, targetFPS: Int) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            if targetFPS >= 60 {
                let formats60 = device.formats.filter { f in
                    f.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 59.9 }
                }
                if !formats60.isEmpty {
                    let best = formats60.first(where: {
                        let d = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                        return d.width == 1280 && d.height == 720
                    }) ?? formats60.first(where: {
                        let d = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                        return d.width == 1920 && d.height == 1080
                    }) ?? formats60.first!
                    
                    if device.activeFormat != best {
                        device.activeFormat = best
                    }
                    let duration = CMTime(value: 1, timescale: 60)
                    device.activeVideoMinFrameDuration = duration
                    device.activeVideoMaxFrameDuration = duration
                    return
                }
            }
             
            let maxFPS = device.activeFormat.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30.0
            let desiredFPS = min(Double(targetFPS), maxFPS)
            let duration = CMTime(value: 1, timescale: Int32(desiredFPS))
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        } catch {
            print("Failed to lock device for frame rate configuration: \(error)")
        }
    }
    
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.isSessionConfigured {
                self.configureSession()
            }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
            isSessionConfigured = true
        }
         
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
         
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        currentInput = nil
        
        let device = currentDevice ?? AVCaptureDevice.default(for: .video)
        if let dev = device,
           let input = try? AVCaptureDeviceInput(device: dev),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
            currentInput = input
            currentDevice = dev
            self.applyFrameRate(to: dev, targetFPS: self.targetFPS)
        }
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        if captureSession.outputs.contains(videoOutput) {
            captureSession.removeOutput(videoOutput)
        }
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        if let connection = videoOutput.connection(with: .video) {
            connection.isEnabled = true
        }
    }
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        var cgImage: CGImage?
        let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        
        if status != noErr || cgImage == nil {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        }
        
        delegate?.cameraManager(self, didOutput: pixelBuffer, previewImage: cgImage)
    }
}
