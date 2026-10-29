//
//  HandPoseDetector.swift
//  Low-B_Pointer
//
//  Created by Tsang Hing Tat on 10/29/26.
//

import Foundation
import CoreGraphics
import Vision

final class HandPoseDetector {
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()
     
    var pinchDownThreshold: CGFloat = 0.26
    var pinchUpThreshold: CGFloat = 0.36
    
    var rightClickThreshold: CGFloat = 0.28
    
    // Previous state for scroll tracking
    private var lastScrollY: CGFloat?
    
    func process(pixelBuffer: CVPixelBuffer) -> HandLandmarks? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                lastScrollY = nil
                return nil
            }
            return extractLandmarks(from: observation)
        } catch {
            lastScrollY = nil
            return nil
        }
    }
    
    private func extractLandmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks {
        var landmarks = HandLandmarks()
        landmarks.confidence = observation.confidence
        
        // Wrist
        landmarks.wrist = point(for: .wrist, in: observation)
        
        // Thumb
        landmarks.thumbCMC = point(for: .thumbCMC, in: observation)
        landmarks.thumbMP = point(for: .thumbMP, in: observation)
        landmarks.thumbIP = point(for: .thumbIP, in: observation)
        landmarks.thumbTip = point(for: .thumbTip, in: observation)
        
        // Index
        landmarks.indexMCP = point(for: .indexMCP, in: observation)
        landmarks.indexPIP = point(for: .indexPIP, in: observation)
        landmarks.indexDIP = point(for: .indexDIP, in: observation)
        landmarks.indexTip = point(for: .indexTip, in: observation)
        
        // Middle
        landmarks.middleMCP = point(for: .middleMCP, in: observation)
        landmarks.middlePIP = point(for: .middlePIP, in: observation)
        landmarks.middleDIP = point(for: .middleDIP, in: observation)
        landmarks.middleTip = point(for: .middleTip, in: observation)
        
        // Ring
        landmarks.ringMCP = point(for: .ringMCP, in: observation)
        landmarks.ringPIP = point(for: .ringPIP, in: observation)
        landmarks.ringDIP = point(for: .ringDIP, in: observation)
        landmarks.ringTip = point(for: .ringTip, in: observation)
        
        // Little
        landmarks.littleMCP = point(for: .littleMCP, in: observation)
        landmarks.littlePIP = point(for: .littlePIP, in: observation)
        landmarks.littleDIP = point(for: .littleDIP, in: observation)
        landmarks.littleTip = point(for: .littleTip, in: observation)
        
        // Hand scale reference (wrist to middle MCP)
        let palmScale: CGFloat
        if let w = landmarks.wrist, let m = landmarks.middleMCP {
            palmScale = max(distance(w, m), 0.05)
        } else {
            palmScale = 0.25 // Fallback default palm scale
        }
        landmarks.palmScale = palmScale
        
        // Distances
        if let thumb = landmarks.thumbTip, let index = landmarks.indexTip {
            let rawDist = distance(thumb, index)
            landmarks.thumbToIndexDistance = rawDist / palmScale
        }
        
        if let thumb = landmarks.thumbTip, let middle = landmarks.middleTip {
            let rawDist = distance(thumb, middle)
            landmarks.thumbToMiddleDistance = rawDist / palmScale
        }
        
        if let thumb = landmarks.thumbTip, let ring = landmarks.ringTip {
            let rawDist = distance(thumb, ring)
            landmarks.thumbToRingDistance = rawDist / palmScale
        }
        
        if let index = landmarks.indexTip, let middle = landmarks.middleTip {
            let rawDist = distance(index, middle)
            landmarks.indexToMiddleDistance = rawDist / palmScale
        }
        
        return landmarks
    }
    
    private func point(for joint: VNHumanHandPoseObservation.JointName, in obs: VNHumanHandPoseObservation) -> CGPoint? {
        guard let pt = try? obs.recognizedPoint(joint), pt.confidence > 0.25 else {
            return nil
        }
        return CGPoint(x: pt.location.x, y: pt.location.y)
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }
}
