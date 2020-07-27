import AVFoundation
import Accelerate

fileprivate let resampler: Resampler = Resampler()

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
        
        // Planar samples
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            let time = measureTime {
                
                buffer.frameLength = buffer.frameCapacity
                let channels = buffer.floatChannelData
                
                var sampleCountSoFar: Int = 0
                
                for index in 0..<frames.count {
                    
                    let frame = frames[index]
                    let frameFloats: [[Float]] = resampler.resample(frame)
                    
                    for channelIndex in 0..<min(2, frameFloats.count) {
                        
                        guard let channel = channels?[channelIndex] else {break}
                        let frameFloatsForChannel: [Float] = frameFloats[channelIndex]
                        
                        cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                    }
                    
                    sampleCountSoFar += Int(frame.sampleCount)
                }
            }
            
            print("\nConstruct PLANAR: \(time * 1000) msec")
            
            return buffer
        }
        
        return nil
    }
}
