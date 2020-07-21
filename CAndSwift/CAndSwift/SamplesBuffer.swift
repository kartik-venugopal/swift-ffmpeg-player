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
    
    var frames: [FrameSamples] = []
    var floats: [Float] = []
    
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    let sampleSize: Int
    let sampleFmt: AVSampleFormat
    
    var isFull: Bool {sampleCount >= maxSampleCount}
    
    init(maxSampleCount: Int32, sampleFmt: AVSampleFormat, sampleSize: Int) {
        
        self.maxSampleCount = maxSampleCount
        self.sampleFmt = sampleFmt
        self.sampleSize = sampleSize
    }
    
    func appendFrame(frame: UnsafeMutablePointer<AVFrame>) {
        
        self.sampleCount += frame.pointee.nb_samples
        frames.append(FrameSamples(frame: frame))
    }
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {

        guard sampleCount > 0 else {return nil}
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            let numChannels = Int(format.channelCount)
            
            buffer.frameLength = buffer.frameCapacity
            let channels = buffer.floatChannelData
            
            var sampleCountSoFar: Int32 = 0
            
            for frame in frames {
                
                let frameSampleCount = Int(frame.sampleCount)
                let dataPointers = frame.byteArrayPointers
            
                for channelIndex in 0..<numChannels {

                    let bytesForChannel = dataPointers[channelIndex]
                    guard let channel = channels?[channelIndex] else {break}

                    switch sampleFmt {
                        
                    // Integer => scale to [-1, 1] and convert to Float.
                    case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:

                        var frameFloatsForChannel: [Float] = []
                        
                        switch sampleSize {

                        case 1:

                            // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                            let reboundData: UnsafePointer<Int8> = bytesForChannel.withMemoryRebound(to: Int8.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int8.max, frameSampleCount, byteOffset: -127)

                        case 2:

                            let reboundData: UnsafePointer<Int16> = bytesForChannel.withMemoryRebound(to: Int16.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int16.max, frameSampleCount)

                        case 4:

                            let reboundData: UnsafePointer<Int32> = bytesForChannel.withMemoryRebound(to: Int32.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int32.max, frameSampleCount)

                        case 8:

                            let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int64.max, frameSampleCount)

                        default: continue

                        }

                        if channelIndex < numChannels {
                            cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1)
                        } else {
                            vDSP_vadd(channel.advanced(by: Int(sampleCountSoFar)), 1, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1, vDSP_Length(frameSampleCount))
                        }

                    case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:

                        let frameFloatsForChannel: UnsafePointer<Float> = bytesForChannel.withMemoryRebound(to: Float.self, capacity: frameSampleCount){$0}
                        
                        if channelIndex < numChannels {
                            cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1)
                        } else {
                            vDSP_vadd(channel.advanced(by: Int(sampleCountSoFar)), 1, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1, vDSP_Length(frameSampleCount))
                        }

                    case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:

                        let doublesForChannel: UnsafePointer<Double> = bytesForChannel.withMemoryRebound(to: Double.self, capacity: frameSampleCount){$0}
                        let frameFloatsForChannel: [Float] = (0..<frameSampleCount).map {Float(doublesForChannel[$0])}
                        
                        if channelIndex < numChannels {
                            cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1)
                        } else {
                            vDSP_vadd(channel.advanced(by: Int(sampleCountSoFar)), 1, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1, vDSP_Length(frameSampleCount))
                        }

                    default:

                        print("Invalid sample format", sampleFmt)
                    }
                }
                
                sampleCountSoFar += frame.sampleCount
            }
            
            return buffer
        }
        
        return nil
    }
    
    func convertToFloatArray<T>(_ unsafeArr: UnsafePointer<T>, _ maxSignedValue: T, _ numSamples: Int, byteOffset: T = 0) -> [Float] where T: SignedInteger {
        return (0..<numSamples).map {Float(Int64(unsafeArr[$0] + byteOffset)) / Float(maxSignedValue)}
    }
}
