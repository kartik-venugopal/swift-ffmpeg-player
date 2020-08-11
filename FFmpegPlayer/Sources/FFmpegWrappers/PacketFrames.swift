import Foundation

/// Holds all frames for a single packet together as a single unit, and performs functions useful when seeking.
class PacketFrames {
    
    var frames: [Frame] = []
    var sampleCount: Int32 = 0
    var packet: Packet?
    
    init() {}
    
    init(from packet: Packet) {
        self.packet = packet
    }
    
    func appendFrame(frame: Frame) {
            
        // Update the sample count, and append the frame.
        self.sampleCount += frame.sampleCount
        frames.append(frame)
    }
    
    func keepLastNSamples(sampleCount: Int32) {
        
        if sampleCount < self.sampleCount {
            
            var samplesSoFar: Int32 = 0
            var firstFrameToKeep: Int = 0

            for (index, frame) in frames.enumerated().reversed() {
                
                let samplesInThisFrame = frame.sampleCount
                print("\nFrame \(index) has \(samplesInThisFrame) samples.")
                
                if samplesSoFar + samplesInThisFrame <= sampleCount {
                    samplesSoFar += samplesInThisFrame
                    print("Frame \(index) will fit. Keeping ALL \(samplesInThisFrame) samples.")
                    
                } else {
                    
                    // Need to truncate frame
                    let samplesToKeep = sampleCount - samplesSoFar
                    samplesSoFar += samplesToKeep
                    frame.keepLastNSamples(sampleCount: samplesToKeep)
                    print("Frame \(index) did NOT fit. Keeping ONLY \(samplesToKeep) samples.")
                }
                
                if samplesSoFar == sampleCount {
                    
                    print("We will keep frames: \(index)-\(frames.count - 1)")
                    
                    firstFrameToKeep = index
                    break
                }
            }
            
            if firstFrameToKeep > 0 {
                frames.removeFirst(firstFrameToKeep)
            }
            
            self.sampleCount = sampleCount
        }
    }
}
