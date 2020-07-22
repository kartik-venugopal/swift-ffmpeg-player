import Foundation
import ffmpeg

class Packet {
    
    let pointer: UnsafeMutablePointer<AVPacket>
    let avPacket: AVPacket
    
    init(_ pointer: UnsafeMutablePointer<AVPacket>) {
        
        self.pointer = pointer
        self.avPacket = pointer.pointee
    }
}

class Frame {
    
    private var _dataArray: [Data]
    var dataArray: [Data] {_dataArray}
    
    var dataPointers: [UnsafePointer<UInt8>] {dataArray.compactMap {$0.withUnsafeBytes{$0}}}
    
    let channelCount: Int
    let sampleCount: Int32
    let lineSize: Int
    
    let sampleFormat: AVSampleFormat
    let sampleSize: Int
    
    init(_ frame: AVFrame, sampleFormat: AVSampleFormat, sampleSize: Int) {
        
        self.channelCount = Int(frame.channels)
        self.sampleCount = frame.nb_samples
        self.lineSize = Int(frame.linesize.0)
        
        self.sampleFormat = sampleFormat
        self.sampleSize = sampleSize
        
        self._dataArray = []
        
        let bufferPointers = frame.dataPointers
        
        for channelIndex in (0..<8) {
            
            guard let buffer = bufferPointers[channelIndex] else {break}
            _dataArray.append(Data(bytes: buffer, count: lineSize))
        }
    }
    
    var dataAsFloatPlanar: [UnsafePointer<Float>] {
        
        var floatPointers: [UnsafePointer<Float>] = []
        let intSampleCount: Int = Int(sampleCount)
        
        for bytesForChannel in dataPointers {
            
            switch sampleFormat {
                
            // Integer => scale to [-1, 1] and convert to Float.
            case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:
                
                var floatsForChannel: [Float]
                
                switch sampleSize {
                    
                case 1:
                    
                    // 8-bit samples
                    
                    // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                    let reboundData: UnsafePointer<Int8> = bytesForChannel.withMemoryRebound(to: Int8.self, capacity: intSampleCount){$0}
                    floatsForChannel = convertToFloatArray(reboundData, Int8.max, intSampleCount, byteOffset: -127)
                    
                case 2:
                    
                    // 16-bit samples
                    
                    let reboundData: UnsafePointer<Int16> = bytesForChannel.withMemoryRebound(to: Int16.self, capacity: intSampleCount){$0}
                    floatsForChannel = convertToFloatArray(reboundData, Int16.max, intSampleCount)
                    
                case 4:
                    
                    // 32-bit samples
                    
                    let reboundData: UnsafePointer<Int32> = bytesForChannel.withMemoryRebound(to: Int32.self, capacity: intSampleCount){$0}
                    floatsForChannel = convertToFloatArray(reboundData, Int32.max, intSampleCount)
                    
                case 8:
                    
                    // 64-bit samples
                    
                    let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: intSampleCount){$0}
                    floatsForChannel = convertToFloatArray(reboundData, Int64.max, intSampleCount)
                    
                default: continue
                    
                }
                
                floatPointers.append(floatsForChannel)
                
            case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
                
                floatPointers.append(bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount){$0})
                
            case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:
                
                let doublesForChannel: UnsafePointer<Double> = bytesForChannel.withMemoryRebound(to: Double.self, capacity: intSampleCount){$0}
                floatPointers.append((0..<intSampleCount).map {Float(doublesForChannel[$0])})
                
            default:
                
                print("Invalid sample format", sampleFormat)
            }
        }
        
        return floatPointers
    }
    
    func convertToFloatArray<T>(_ unsafeArr: UnsafePointer<T>, _ maxSignedValue: T, _ numSamples: Int, byteOffset: T = 0) -> [Float] where T: SignedInteger {
        return (0..<numSamples).map {Float(Int64(unsafeArr[$0] + byteOffset)) / Float(maxSignedValue)}
    }
}
