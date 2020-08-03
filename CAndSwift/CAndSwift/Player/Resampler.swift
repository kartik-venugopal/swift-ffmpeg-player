import AVFoundation
import Accelerate

///
/// Performs conversion of PCM audio samples to the standard sample format suitable for playback in an AVAudioEngine,
/// i.e. 32-bit floating point non-interleaved. Sample rate and channel layout are not affected by this process.
///
class Resampler {
    
    static let instance = Resampler()
    private static let defaultChannelLayout: Int64 = Int64(AV_CH_LAYOUT_STEREO)
    
    var outData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    
    private init() {
        
        outData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 8)
        outData.initialize(to: nil)
    }
    
    func prepare(channelCount: Int32, sampleCount: Int32) {
        av_samples_alloc(outData, nil, channelCount, sampleCount, AV_SAMPLE_FMT_FLTP, 0)
    }
    
    func deallocate() {
        av_freep(&outData[0])
    }
    
    func resample(_ frame: BufferedFrame, copyTo audioBuffer: AVAudioPCMBuffer, withOffset offset: Int) {
        
        let sampleCount: Int32 = frame.sampleCount
        
        var swr: OpaquePointer? = swr_alloc()
        let uswr = UnsafeMutableRawPointer(swr)
        
        let channelLayout = frame.channelLayout > 0 ? Int64(frame.channelLayout) : Self.defaultChannelLayout
        av_opt_set_channel_layout(uswr, "in_channel_layout", channelLayout, 0)
        av_opt_set_channel_layout(uswr, "out_channel_layout", channelLayout, 0)
        
        let sampleRate = Int64(frame.sampleRate)
        av_opt_set_int(uswr, "in_sample_rate", sampleRate, 0)
        av_opt_set_int(uswr, "out_sample_rate", sampleRate, 0)
        
        av_opt_set_sample_fmt(uswr, "in_sample_fmt", frame.sampleFormat.avFormat, 0)
        av_opt_set_sample_fmt(uswr, "out_sample_fmt", AV_SAMPLE_FMT_FLTP, 0)
        
        swr_init(swr)
        
        // Destination
        
        let outDataPtr: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> = UnsafeMutableBufferPointer(start: outData, count: frame.channelCount)
        
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
