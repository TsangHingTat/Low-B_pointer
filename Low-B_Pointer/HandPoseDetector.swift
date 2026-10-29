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
