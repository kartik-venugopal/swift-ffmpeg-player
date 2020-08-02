import AVFoundation
import Accelerate

class Resampler {
    
    static let instance = Resampler()
    
    // TODO: In Player, limit the number of buffer samples to this value
    static let maxSamplesPerBuffer: Int32 = 355000 * 10
    
    var outData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    
    private let defaultChannelLayout: Int64 = Int64(AV_CH_LAYOUT_STEREO)
    
    private init() {
        
        let time = measureTime {
            
        // Initialize memory space to hold the output of conversions. This memory space will be reused for all conversions.
        // It is inefficient to do this repeatedly, once per conversion. So do it once and reuse the space.
        outData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 8)
        outData.initialize(to: nil)
        
        // Assume a maximum required memory space corresponding to sampleRate=352,800Hz, duration=10sec, channelCount=8.
        // This should accommodate (be big enough for) all possible conversions.
        av_samples_alloc(outData, nil, 8, Self.maxSamplesPerBuffer, AV_SAMPLE_FMT_FLTP, 0)
        
        }
        
        print("\nTook \(time * 1000) msec to allocate space for Resampler.")
    }
    
    func resample(_ frame: BufferedFrame, copyTo audioBuffer: AVAudioPCMBuffer, withOffset offset: Int) {
        
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
        
        _ = frame.rawDataPointers.withMemoryRebound(to: UnsafePointer<UInt8>?.self) { inDataPtr in
            swr_convert(swr, outDataPtr.baseAddress, sampleCount, inDataPtr.baseAddress!, sampleCount)
        }
        
        swr_free(&swr)
        
        copyOutputToAudioBuffer(frame, buffer: audioBuffer, withOffset: offset)
    }
    
    private func copyOutputToAudioBuffer(_ frame: BufferedFrame, buffer: AVAudioPCMBuffer, withOffset offset: Int) {
        
        let channels = buffer.floatChannelData
        let intSampleCount: Int = Int(frame.sampleCount)
        
        for channelIndex in 0..<frame.channelCount {
            
            guard let bytesForChannel = outData[channelIndex], let channel = channels?[channelIndex] else {break}
            
            bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount)
            {(pointer: UnsafeMutablePointer<Float>) in
                cblas_scopy(frame.sampleCount, pointer, 1, channel.advanced(by: offset), 1)
            }
        }
    }
}
