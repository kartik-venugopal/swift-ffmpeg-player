import Foundation

fileprivate let max8BitFloatVal: Float = Float(Int8.max)
fileprivate let max16BitFloatVal: Float = Float(Int16.max)
fileprivate let max32BitFloatVal: Float = Float(Int32.max)
fileprivate let max64BitDoubleVal: Double = Double(Int64.max)

class Frame {
    
    private var _dataArray: [Data]
    var dataArray: [Data] {_dataArray}
    
    var dataPointers: [UnsafePointer<UInt8>] {dataArray.compactMap {$0.withUnsafeBytes{$0}}}
    
    let channelCount: Int
    let sampleCount: Int32
    let lineSize: Int
    
    let sampleFormat: SampleFormat
    
    init(_ frame: UnsafeMutablePointer<AVFrame>, sampleFormat: SampleFormat) {
        
        self.channelCount = Int(frame.pointee.channels)
        self.sampleCount = frame.pointee.nb_samples
        self.lineSize = Int(frame.pointee.linesize.0)
        
        self.sampleFormat = sampleFormat
        
        self._dataArray = []
        
        let bufferPointers = frame.pointee.dataPointers
        
        for channelIndex in (0..<8) {
            
            guard let buffer = bufferPointers[channelIndex] else {break}
            _dataArray.append(Data(bytes: buffer, count: lineSize))
        }
    }
    
    var dataAsFloatPlanar: [[Float]] {
        
        // TODO: Handle non-planar (packed/interleaved) samples too !
        
        var allFloatData: [[Float]] = []
        let intSampleCount: Int = Int(sampleCount)
        
        for bytesForChannel in dataPointers {
            
            switch sampleFormat.avFormat {
                
            // Integer => scale to [-1, 1] and convert to Float.
            case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:
                
                var floatsForChannel: [Float]
                
                switch sampleFormat.size {
                    
                case 1:
                    
                    // (Unsigned) 8-bit integer samples
                    
                    // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                    let reboundData: UnsafePointer<Int8> = bytesForChannel.withMemoryRebound(to: Int8.self, capacity: intSampleCount){$0}
                    floatsForChannel = (0..<intSampleCount).map {Float(reboundData[$0] - 127) / max8BitFloatVal}
                    
                case 2:
                    
                    // Signed 16-bit integer samples
                    
                    let reboundData: UnsafePointer<Int16> = bytesForChannel.withMemoryRebound(to: Int16.self, capacity: intSampleCount){$0}
                    floatsForChannel = (0..<intSampleCount).map {Float(reboundData[$0]) / max16BitFloatVal}
                    
                case 4:
                    
                    // Signed 32-bit integer samples
                    
                    let reboundData: UnsafePointer<Int32> = bytesForChannel.withMemoryRebound(to: Int32.self, capacity: intSampleCount){$0}
                    floatsForChannel = (0..<intSampleCount).map {Float(reboundData[$0]) / max32BitFloatVal}
                    
                case 8:
                    
                    // Signed 64-bit integer samples
                    
                    let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: intSampleCount){$0}
                    floatsForChannel = (0..<intSampleCount).map {Float(Double(reboundData[$0]) / max64BitDoubleVal)}
                    
                default: continue
                    
                }
                
                allFloatData.append(floatsForChannel)
                
            case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
                
                // Floating point samples
                
                let floatsForChannel = Array(UnsafeBufferPointer(start: bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount){$0}, count: intSampleCount))
                allFloatData.append(floatsForChannel)
                
            case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:
                
                // Double-precision floating point samples
                
                let doublesForChannel: UnsafePointer<Double> = bytesForChannel.withMemoryRebound(to: Double.self, capacity: intSampleCount){$0}
                allFloatData.append((0..<intSampleCount).map {Float(doublesForChannel[$0])})
                
            default:
                
                print("Invalid sample format", sampleFormat.name)
            }
        }
        
        return allFloatData
    }
}

extension AVFrame {

    var dataPointers: [UnsafeMutablePointer<UInt8>?] {
        Array(UnsafeBufferPointer(start: self.extended_data, count: 8))
    }
}
