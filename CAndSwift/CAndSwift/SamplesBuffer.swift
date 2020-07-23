import AVFoundation
import Accelerate
import ffmpeg

class SamplesBuffer {
    
    var frames: [Frame] = []
    
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    var isFull: Bool {sampleCount >= maxSampleCount}
    
    init(maxSampleCount: Int32) {
        self.maxSampleCount = maxSampleCount
    }
    
    func appendFrame(frame: Frame) {
        
        self.sampleCount += frame.sampleCount
        frames.append(frame)
    }
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {

        guard sampleCount > 0 else {return nil}
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            let numChannels = Int(format.channelCount)
            
            buffer.frameLength = buffer.frameCapacity
            let channels = buffer.floatChannelData
            
            var sampleCountSoFar: Int = 0
            
            for frame in frames {
                
                let frameFloatData: [[Float]] = frame.dataAsFloatPlanar
            
                for channelIndex in 0..<numChannels {
                    
                    guard let channel = channels?[channelIndex] else {break}
                    let frameFloatsForChannel: [Float] = frameFloatData[channelIndex]
                    
                    cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                }
                
                sampleCountSoFar += Int(frame.sampleCount)
            }
            
            return buffer
        }
        
        return nil
    }
}
