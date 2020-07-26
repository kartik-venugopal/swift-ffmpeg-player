import Foundation

// The 0.5 correction is added because, for signed integers, abs(min) = abs(max) + 1
// (eg. for Int8, the range is -128...127, which would result in some converted Float sample values being < -1.
// The 0.5 correction shifts the range up so that it is centered exactly at 0 which is where our samples should
// be centered (-1...1).

fileprivate let max8BitFloatVal: Float = Float(Int8.max) + 0.5
fileprivate let max16BitFloatVal: Float = Float(Int16.max) + 0.5
fileprivate let max32BitFloatVal: Float = Float(Int32.max) + 0.5
fileprivate let max64BitDoubleVal: Double = Double(Int64.max) + 0.5

protocol SignedIntegerFrameProtocol {
    
}

protocol UnsignedIntegerFrameProtocol {
    
}

class Frame: Hashable {
    
    static func == (lhs: Frame, rhs: Frame) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
    }
    
    private var _dataArray: [Data]
    var dataArray: [Data] {_dataArray}
    
    var dataPointers: [UnsafePointer<UInt8>] {dataArray.compactMap {$0.withUnsafeBytes{$0}}}
    
    let channelCount: Int
    let sampleCount: Int32
    let lineSize: Int
    
    let sampleFormat: SampleFormat
    
    let timestamp: Int64
    
    init(_ frame: UnsafeMutablePointer<AVFrame>, sampleFormat: SampleFormat) {
        
        self.timestamp = frame.pointee.best_effort_timestamp
        
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
    
    var planarFloatData: [[Float]] {
        
        var allFloatData: [[Float]] = []
        let intSampleCount: Int = Int(sampleCount)
        
        for bytesForChannel in dataPointers {
            
            let floatsForChannel: [Float]
            
            switch sampleFormat.avFormat {
                
            // Integer => scale to [-1, 1] and convert to Float.

            // Unsigned 8-bit integer
            case AV_SAMPLE_FMT_U8P:
                
                // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                let reboundData: UnsafePointer<Int8> = bytesForChannel.withMemoryRebound(to: Int8.self, capacity: intSampleCount){$0}
                floatsForChannel = (0..<intSampleCount).map {Float(reboundData[$0] - 127) / max8BitFloatVal}
                
            // Signed 16-bit integer
            case AV_SAMPLE_FMT_S16P:
                
                let reboundData: UnsafePointer<Int16> = bytesForChannel.withMemoryRebound(to: Int16.self, capacity: intSampleCount){$0}
                floatsForChannel = (0..<intSampleCount).map {(Float(reboundData[$0]) + 0.5) / max16BitFloatVal}
                
//                let swr = swr_alloc()
//                av_opt_set_channel_layout(swr, "in_channel_layout", AV_CH_LAYOUT_STEREO, <#T##search_flags: Int32##Int32#>)
//                av_samples_alloc(<#T##audio_data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!##UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!#>, <#T##linesize: UnsafeMutablePointer<Int32>!##UnsafeMutablePointer<Int32>!#>, <#T##nb_channels: Int32##Int32#>, <#T##nb_samples: Int32##Int32#>, <#T##sample_fmt: AVSampleFormat##AVSampleFormat#>, <#T##align: Int32##Int32#>)

            // Signed 32-bit integer
            case AV_SAMPLE_FMT_S32P:
                
                let reboundData: UnsafePointer<Int32> = bytesForChannel.withMemoryRebound(to: Int32.self, capacity: intSampleCount){$0}
                floatsForChannel = (0..<intSampleCount).map {Float(reboundData[$0]) / max32BitFloatVal}

            // Signed 64-bit integer
            case AV_SAMPLE_FMT_S64P:
                
                let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: intSampleCount){$0}
                floatsForChannel = (0..<intSampleCount).map {Float(Double(reboundData[$0]) / max64BitDoubleVal)}

            // Floating point
            case AV_SAMPLE_FMT_FLTP:
                
                floatsForChannel = Array(UnsafeBufferPointer(start: bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount){$0}, count: intSampleCount))

            // Double-precision floating point
            case AV_SAMPLE_FMT_DBLP:
                
                let doublesForChannel: UnsafePointer<Double> = bytesForChannel.withMemoryRebound(to: Double.self, capacity: intSampleCount){$0}
                floatsForChannel = (0..<intSampleCount).map {Float(doublesForChannel[$0])}
                
            default:
                
                print("Invalid sample format", sampleFormat.name)
                return []
            }
            
            allFloatData.append(floatsForChannel)
        }
        
        return allFloatData
    }
    
    static var convTime: Double = 0
    
    var packedFloatData: [Float] {
        
        let sampleCountForAllChannels: Int = Int(sampleCount) * channelCount
        
        let allBytes = dataPointers[0]
            
        switch sampleFormat.avFormat {
            
        // Integer => scale to [-1, 1] and convert to Float.

        // Unsigned 8-bit integer
        case AV_SAMPLE_FMT_U8:
            
            // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
            let reboundData: UnsafePointer<Int8> = allBytes.withMemoryRebound(to: Int8.self, capacity: sampleCountForAllChannels){$0}
            return (0..<sampleCountForAllChannels).map {Float(reboundData[$0] - 127) / max8BitFloatVal}
            
        // Signed 16-bit integer
        case AV_SAMPLE_FMT_S16:
            
            let reboundData: UnsafePointer<Int16> = allBytes.withMemoryRebound(to: Int16.self, capacity: sampleCountForAllChannels){$0}
            return (0..<sampleCountForAllChannels).map {(Float(reboundData[$0]) + 0.5) / max16BitFloatVal}

        // Signed 32-bit integer
        case AV_SAMPLE_FMT_S32:
            
            var floats: [Float] = []
            
            let ctime = measureTime {
                
                let reboundData: UnsafePointer<Int32> = allBytes.withMemoryRebound(to: Int32.self, capacity: sampleCountForAllChannels){$0}
                floats = (0..<sampleCountForAllChannels).map {Float(reboundData[$0]) / max32BitFloatVal}
            }
            
            Self.convTime += ctime
            return floats
            
        // Signed 64-bit integer
        case AV_SAMPLE_FMT_S64:
            
            let reboundData: UnsafePointer<Int64> = allBytes.withMemoryRebound(to: Int64.self, capacity: sampleCountForAllChannels){$0}
            return (0..<sampleCountForAllChannels).map {Float(Double(reboundData[$0]) / max64BitDoubleVal)}

        // Floating point
        case AV_SAMPLE_FMT_FLT:
        
            return Array(UnsafeBufferPointer(start: allBytes.withMemoryRebound(to: Float.self, capacity: sampleCountForAllChannels){$0}, count: sampleCountForAllChannels))

        // Double-precision floating point
        case AV_SAMPLE_FMT_DBL:
            
            let doublesForChannel: UnsafePointer<Double> = allBytes.withMemoryRebound(to: Double.self, capacity: sampleCountForAllChannels){$0}
            return (0..<sampleCountForAllChannels).map {Float(doublesForChannel[$0])}
        
        default:
        
            print("Invalid sample format", sampleFormat.name)
            return []
        }
    }
}

class Unsigned8BitIntegerFrame: Frame {

    var floatData: [[Float]] {
        
        var allFloatData: [[Float]] = []
        let intSampleCount: Int = Int(sampleCount)
        
        for bytesForChannel in dataPointers {
            
            // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
            let reboundData: UnsafePointer<UInt8> = bytesForChannel.withMemoryRebound(to: UInt8.self, capacity: intSampleCount){$0}
            let floatsForChannel: [Float] = (0..<intSampleCount).map {Float(Int16(reboundData[$0]) - 128) / max8BitFloatVal}
            
            allFloatData.append(floatsForChannel)
        }
        
        return allFloatData
    }
}

class SignedIntegerFrame<T>: Frame where T : SignedInteger {
    
    // Override this !
    var maxSignedValueAsFloat: Float {0}

    var floatData: [[Float]] {
        
        let intSampleCount: Int = Int(sampleCount)
        
        return dataPointers.map {bytesForChannel in
            
            let reboundData: UnsafePointer<T> = bytesForChannel.withMemoryRebound(to: T.self, capacity: intSampleCount){$0}
            return (0..<intSampleCount).map {Float(reboundData[$0]) / maxSignedValueAsFloat}
        }
    }
}

class Signed16BitIntegerFrame: SignedIntegerFrame<Int16> {
    override var maxSignedValueAsFloat: Float {max16BitFloatVal}
}

class Signed32BitIntegerFrame: SignedIntegerFrame<Int32> {
    override var maxSignedValueAsFloat: Float {max32BitFloatVal}
}

class Signed64BitIntegerFrame: Frame {
    
    var floatData: [[Float]] {
        
        let intSampleCount: Int = Int(sampleCount)
        
        return dataPointers.map {bytesForChannel in
            
            // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
            let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: intSampleCount){$0}
            return (0..<intSampleCount).map {Float(Double(reboundData[$0]) / max64BitDoubleVal)}
        }
    }
}

extension AVFrame {
    
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {
        Array(UnsafeBufferPointer(start: self.extended_data, count: 8))
    }
}
