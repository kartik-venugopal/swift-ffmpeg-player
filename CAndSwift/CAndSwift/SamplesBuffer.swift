import AVFoundation
import Accelerate

class SamplesBuffer {
    
    // TODO: Add a destroy method to release/free all the memory after the buffer has been scheduled for playback
    
    var frames: [BufferedFrame] = []
    
    let sampleFormat: SampleFormat
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    var isFull: Bool {sampleCount >= maxSampleCount}
    
    init(sampleFormat: SampleFormat, maxSampleCount: Int32) {
        
        self.sampleFormat = sampleFormat
        self.maxSampleCount = maxSampleCount
    }
    
    func appendFrame(frame: BufferedFrame) {
        
        self.sampleCount += frame.sampleCount
        frames.append(frame)
    }
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        
        guard sampleCount > 0 else {return nil}
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            buffer.frameLength = buffer.frameCapacity
            let channels = buffer.floatChannelData
            
            var sampleCountSoFar: Int = 0
            
            for index in 0..<frames.count {
                
                let frame = frames[index]
                let frameFloats: [UnsafePointer<Float>] = Resampler.instance.resample(frame)
                
                for channelIndex in 0..<min(2, frameFloats.count) {
                    
                    guard let channel = channels?[channelIndex] else {break}
                    let frameFloatsForChannel = frameFloats[channelIndex]
                    
                    cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                }
                
                sampleCountSoFar += Int(frame.sampleCount)
            }
            
            return buffer
        }
        
        return nil
    }
    
    deinit {
        // TODO: Free all the allocated memory
    }
}
