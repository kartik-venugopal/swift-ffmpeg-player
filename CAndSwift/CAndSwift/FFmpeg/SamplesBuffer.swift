import AVFoundation
import Accelerate
import ffmpeg

// Samples for a single frame
class FrameSamples {
    
    var rawByteArrays: [Data] = []
    var byteArrayPointers: [UnsafePointer<UInt8>] {rawByteArrays.compactMap {$0.withUnsafeBytes{$0}}}
    let sampleCount: Int32
    
    init(frame: UnsafeMutablePointer<AVFrame>) {
        
        let buffers = frame.pointee.datas()
        let linesize = Int(frame.pointee.linesize.0)
        
        for channelIndex in (0..<8) {
            
            guard let buffer = buffers[channelIndex] else {break}
            rawByteArrays.append(Data(bytes: buffer, count: linesize))
        }
        
        self.sampleCount = frame.pointee.nb_samples
    }
}

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
                
                let frameFloatData: [UnsafePointer<Float>] = frame.dataAsFloatPlanar
                let frameSampleCount = Int(frame.sampleCount)
            
                for channelIndex in 0..<numChannels {
                    
                    guard let channel = channels?[channelIndex] else {break}
                    let frameFloatsForChannel: UnsafePointer<Float> = frameFloatData[channelIndex]
                    
                    if channelIndex < numChannels {
                        
                        // Mono/Stereo audio (up to 2 channels)
                        cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                        
                    } else {
                        
                        // Downmixing from surround sound (eg. 5.1 to stereo)
                        vDSP_vadd(channel.advanced(by: sampleCountSoFar), 1, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1, vDSP_Length(frameSampleCount))
                    }
                }
                
                sampleCountSoFar += Int(frame.sampleCount)
            }
            
            return buffer
        }
        
        return nil
    }
    
    func convertToFloatArray<T>(_ unsafeArr: UnsafePointer<T>, _ maxSignedValue: T, _ numSamples: Int, byteOffset: T = 0) -> [Float] where T: SignedInteger {
        return (0..<numSamples).map {Float(Int64(unsafeArr[$0] + byteOffset)) / Float(maxSignedValue)}
    }
}

extension AVFrame {

    mutating func datas() -> [UnsafeMutablePointer<UInt8>?] {
        let ptr = UnsafeBufferPointer(start: self.extended_data, count: 8)
        let arr = Array(ptr)
        return arr
    }
    
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {
        Array(UnsafeBufferPointer(start: self.extended_data, count: 8))
    }
}
