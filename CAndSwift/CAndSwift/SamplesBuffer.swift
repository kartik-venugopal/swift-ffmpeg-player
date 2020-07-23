import AVFoundation
import Accelerate
import ffmpeg

class SamplesBuffer {
    
    var frames: [Frame] = []
    
    let sampleFormat: SampleFormat
    
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    var isFull: Bool {sampleCount >= maxSampleCount}
    
    init(sampleFormat: SampleFormat, maxSampleCount: Int32) {
        
        self.sampleFormat = sampleFormat
        self.maxSampleCount = maxSampleCount
    }
    
    func appendFrame(frame: Frame) {
        
        self.sampleCount += frame.sampleCount
        frames.append(frame)
    }
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {

        guard sampleCount > 0 else {return nil}

        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {

            buffer.frameLength = buffer.frameCapacity
            let channels = buffer.floatChannelData
            
            let numChannels = Int(format.channelCount)
            var sampleCountSoFar: Int = 0
            
            for frame in frames {
                
                if sampleFormat.isPlanar {
                    
                    let frameFloats: [[Float]] = frame.planarFloatData
                    
                    for channelIndex in 0..<min(2, frameFloats.count) {
                        
                        guard let channel = channels?[channelIndex] else {break}
                        let frameFloatsForChannel: [Float] = frameFloats[channelIndex]
                        
                        cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                    }
                    
                    sampleCountSoFar += Int(frame.sampleCount)
                    
                } else { // Packed
                    
                    let packedFloats: [Float] = frame.packedFloatData
                    
                    for channelIndex in 0..<numChannels {
                        
                        guard let channel = channels?[channelIndex] else {break}
                        cblas_scopy(Int32(packedFloats.count / numChannels), packedFloats, Int32(numChannels), channel.advanced(by: sampleCountSoFar), 1)
                    }
                    
                    sampleCountSoFar += Int(frame.sampleCount)
                }
            }

            return buffer
        }
        
        return nil
    }
}
