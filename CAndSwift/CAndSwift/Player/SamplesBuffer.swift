import AVFoundation
import Accelerate

///
/// A temporary container that accumulates / buffers frames until the number of frames
/// is deemed large enough to schedule for playback.
///
/// Also assists in constructing AVAudioPCMBuffer objects that can be scheduled for playback.
///
class SamplesBuffer {
    
    var frames: [BufferedFrame] = []
    
    let sampleFormat: SampleFormat
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    init(sampleFormat: SampleFormat, maxSampleCount: Int32) {
        
        self.sampleFormat = sampleFormat
        self.maxSampleCount = maxSampleCount
    }
    
    // Returns whether or not the frame was appended to the buffer.
    // Will be false if/when the new frame's sample count would cause the buffer to exceed its maxSampleCount.
    func appendFrame(frame: BufferedFrame) -> Bool {
        
        if self.sampleCount + frame.sampleCount <= maxSampleCount {
            
            self.sampleCount += frame.sampleCount
            frames.append(frame)
            
            return true
        }
        
        return false
    }
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        
        guard sampleCount > 0 else {return nil}
        
        if let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            audioBuffer.frameLength = audioBuffer.frameCapacity
            let channels = audioBuffer.floatChannelData
            
            var sampleCountSoFar: Int = 0
            
            for frame in frames {
                
                if sampleFormat.needsResampling {
                    
                    Resampler.instance.resample(frame, copyTo: audioBuffer, withOffset: sampleCountSoFar)
                    
                } else {
                    
                    let frameFloats: [UnsafePointer<Float>] = frame.playableFloatPointers
                    
                    for channelIndex in 0..<frameFloats.count {
                        
                        guard let channel = channels?[channelIndex] else {break}
                        let frameFloatsForChannel = frameFloats[channelIndex]
                        
                        cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                    }
                }
                
                sampleCountSoFar += Int(frame.sampleCount)
            }
            
            return audioBuffer
        }
        
        return nil
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}
        
        frames.forEach {$0.destroy()}
        destroyed = true
    }
    
    deinit {
        destroy()
    }
}
