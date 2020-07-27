import Foundation

class Resampler {
    
    var outData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    
    private let defaultChannelLayout: Int64 = Int64(AV_CH_LAYOUT_STEREO)
    
    init() {
        
        let time = measureTime {
            
        // Initialize memory space to hold the output of conversions. This memory space will be reused for all conversions.
        // It is inefficient to do this repeatedly, once per conversion. So do it once and reuse the space.
        outData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 8)
        outData.initialize(to: nil)
        
        // Assume a maximum required memory space corresponding to sampleRate=352,800Hz, duration=10sec, channelCount=8.
        // This should accommodate (be big enough for) all possible conversions.
        av_samples_alloc(outData, nil, 8, 352800 * 60, AV_SAMPLE_FMT_FLTP, 0)
        
        }
        
        print("\nTook \(time * 1000) msec to allocate space for Resampler.")
    }
    
    private func doResample(_ frame: Frame) -> [[Float]] {
        
        let sampleCount: Int32 = frame.sampleCount
        
        var swr: OpaquePointer? = swr_alloc()
        let uswr = UnsafeMutableRawPointer(swr)
        
        let channelLayout = frame.channelLayout > 0 ? Int64(frame.channelLayout) : defaultChannelLayout
        av_opt_set_channel_layout(uswr, "in_channel_layout", channelLayout, 0)
        av_opt_set_channel_layout(uswr, "out_channel_layout", channelLayout, 0)
        
        let sampleRate = Int64(frame.sampleRate)
        av_opt_set_int(uswr, "in_sample_rate", sampleRate, 0)
        av_opt_set_int(uswr, "out_sample_rate", sampleRate, 0)
        
        av_opt_set_sample_fmt(uswr, "in_sample_fmt", frame.sampleFormat.avFormat, 0)
        av_opt_set_sample_fmt(uswr, "out_sample_fmt", AV_SAMPLE_FMT_FLTP, 0)
        
        swr_init(swr)
        
        // Destination
        
        let outDataPtr: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> = UnsafeMutableBufferPointer(start: outData, count: 8)
        
        _ = frame.dataPointers.withMemoryRebound(to: UnsafePointer<UInt8>?.self) { inDataPtr in
            swr_convert(swr, outDataPtr.baseAddress, sampleCount, inDataPtr.baseAddress!, sampleCount)
        }
        
        swr_free(&swr)
        
        return pointerToFloats(outData, frame)
    }
    
    func resample(_ frame: Frame) -> [[Float]] {
        
        if frame.sampleFormat.needsResampling {
            return doResample(frame)
        }
        
        return pointerToFloats(frame.dataPointers.baseAddress!, frame)
    }
    
    private func pointerToFloats(_ ptr: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, _ frame: Frame) -> [[Float]] {
        
        var floats: [[Float]] = []
        let intSampleCount: Int = Int(frame.sampleCount)
        
        for channelIndex in 0..<frame.channelCount {
            
            guard let bytesForChannel = ptr[channelIndex] else {break}
            
            // TODO: Can we simply read the floats here instead of returning the pointer ? Is this safe ???
            floats.append(bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount)
            {Array(UnsafeBufferPointer(start: $0, count: intSampleCount))})
        }
        
        return floats
    }
}
