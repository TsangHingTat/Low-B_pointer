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
            }
            self.captureSession.commitConfiguration()
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
        
        // Use 1280x720 or High for balance of speed and clarity
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // Clear existing inputs/outputs if any
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
