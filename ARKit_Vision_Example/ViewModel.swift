//
//  ViewModel.swift
//  ARKit_Vision_Example
//
//  Created by Eldar Eliav on 06/02/2021.
//

import Foundation
import Vision
import ARKit

// This is just an educational example.
// A good example of how to properly implement this topic
// please checkout the ARCarGuidePoC project: https://github.com/eldare/ARCarGuidePoC

struct ResultModel {
    var isCat: Bool
    var rawBoundingBox: CGRect
}

class ViewModel {
    typealias SearchCompletion = (_ results: ResultModel?, _ arFrame: ARFrame) -> Void

    private var searchCompletion: SearchCompletion?
    private let serialQueue: DispatchQueue = {
        let date = Date().description
        let queue = DispatchQueue(label: "modelDetection_\(date)",
                                  qos: .userInteractive)
        return queue
    }()
    private var vnRequests = [VNRequest]()
    private var inProcessARFrame: ARFrame?

    init() {

        // STEP 4.
        // Prepare Vision Request - Detect animals

        let vnRequest = VNRecognizeAnimalsRequest(completionHandler: { [weak self] request, error in
            var visionResult: ResultModel? = nil

            defer {
                // STEP 6.2.
                // Call completion with Result - on main thread

                DispatchQueue.main.async { [weak self] in
                    guard let inProcessARFrame = self?.inProcessARFrame else { return }

                    self?.searchCompletion?(visionResult, inProcessARFrame)

                    // STEP 6.3.
                    // just another ODD way to slow down the processing - it's really expensive
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self?.inProcessARFrame = nil
                    }
                }
            }

            // STEP 6.
            // Vision Result is here

            if let error = error {
                print("\(error)")
            }

            guard let results = request.results as? [VNRecognizedObjectObservation],
                  let result = results.first else {
                return
            }

            // STEP 6.1.
            // We only care about a single result of a cat

            guard let bestLabelIdentifier = result.labels.first?.identifier else { return }

            visionResult = ResultModel(
                isCat: bestLabelIdentifier == "Cat",
                rawBoundingBox: result.boundingBox
            )
        })  // end Vision Request result completion

        // STEP 4.1.
        // Append this request to Vision Requests list

        vnRequests.append(vnRequest)
    }

    func search(in arFrame: ARFrame,
                completion: @escaping SearchCompletion) {
        guard inProcessARFrame == nil else {
            // progress only if no AR frame is being proccessed
            return
        }

        // STEP 5.
        // Update Search completion,
        // and Execute Vision Request async.

        searchCompletion = completion

        serialQueue.async { [weak self] in
            guard let self = self else {
                print("self is nil")
                return
            }
            do {
                self.inProcessARFrame = arFrame
                let requestHandler = VNImageRequestHandler(cvPixelBuffer: arFrame.capturedImage, options: [:])
                try requestHandler.perform(self.vnRequests)
            }
            catch {
                print(error)
            }
        }
    }
}
