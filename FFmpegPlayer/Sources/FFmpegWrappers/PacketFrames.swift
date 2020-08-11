import Foundation

/// Holds all frames for a single packet together as a single unit, and performs functions useful when seeking.
class PacketFrames {
    
    var frames: [Frame] = []
    var sampleCount: Int32 = 0
    
    func appendFrame(_ frame: Frame) {
            
        // Update the sample count, and append the frame.
        self.sampleCount += frame.sampleCount
        frames.append(frame)
    }
    
    func keepLastNSamples(sampleCount: Int32) {
        
        if sampleCount < self.sampleCount {
            
            var samplesSoFar: Int32 = 0
            var firstFrameToKeep: Int = 0

            // Iterate the frames in reverse, counting the accumulated samples till we have enough.
            for (index, frame) in frames.enumerated().reversed() {
                
                let samplesInThisFrame = frame.sampleCount
                
                if samplesSoFar + samplesInThisFrame <= sampleCount {
                    
                    // This frame fits in its entirety.
                    samplesSoFar += samplesInThisFrame
                    
                } else {
                    
                    // This frame fits partially. Need to truncate it.
                    let samplesToKeep = sampleCount - samplesSoFar
                    samplesSoFar += samplesToKeep
                    frame.keepLastNSamples(sampleCount: samplesToKeep)
                }
                
                if samplesSoFar == sampleCount {
                    
                    // We have enough samples. Note down the index of this frame.
                    firstFrameToKeep = index
                    break
                }
            }
            
            // Discard any surplus frames.
            if firstFrameToKeep > 0 {
                frames.removeFirst(firstFrameToKeep)
            }
            
            // Update the sample count.
            self.sampleCount = sampleCount
        }
    }
}
