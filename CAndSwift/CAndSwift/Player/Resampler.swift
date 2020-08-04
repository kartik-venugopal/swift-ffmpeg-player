import AVFoundation
import Accelerate

///
/// Performs conversion of PCM audio samples to the standard sample format suitable for playback in an AVAudioEngine,
/// i.e. 32-bit floating point non-interleaved (aka planar). Sample rate and channel layout are not affected by this process.
///
/// ```
/// Resampling is only required when codecs produce PCM samples that are not already in
/// the required standard format.
/// ```
///
class Resampler {
    
    ///
    /// Singleton instance of this class that is shared by different objects.
    ///
    static let instance = Resampler()
    
    ///
    /// The default channel layout to assume when the channel layout for an audio file cannot be determined.
    ///
    /// Should never have to be used.
    ///
    private static let defaultChannelLayout: Int64 = Int64(AV_CH_LAYOUT_STEREO)
    
    ///
    /// Pointers to the memory space allocated for the resampler's output samples. Each pointer points to
    /// space allocated to samples for a single channel.
    ///
    var outputData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    
    ///
    /// The channel count for the output samples.
    ///
    var allocatedChannelCount: Int32 = 0
    
    ///
    /// The number of output samples (per channel).
    ///
    var allocatedSampleCount: Int32 = 0
    
    private init() {
        
        // Allocate space for up to 8 channels of sample data.
        outputData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 8)
        outputData.initialize(to: nil)
    }
    
    ///
    /// Prepares the resampler to resample PCM samples for a file.
    ///
    /// This function should be called exactly once prior to the start of playback of the file.
    ///
    func prepareForFile(channelCount: Int32, sampleCount: Int32) {
        
        av_samples_alloc(outputData, nil, channelCount, sampleCount, AV_SAMPLE_FMT_FLTP, 0)
        
        self.allocatedChannelCount = channelCount
        self.allocatedSampleCount = sampleCount
    }
    
    ///
    /// Prepares the resampler to resample PCM samples for a single frame buffer.
    ///
    /// This function should be called exactly once prior to the construction of an audio buffer from a frame buffer's samples.
    ///
    /// - Parameter sampleCount:    The number of samples in the frame buffer for which this function was called.
    ///                             This will determine how much space needs to be allocated to hold the output samples for this buffer.
    ///
    ///  # Notes #
    ///
    /// Ideally, when **prepareForFile()** is invoked, and space is allocated, calling this function should not result in repeated re-allocation of space.
    /// In other words, the space allocated by **prepareForFile()** should be enough for all frame buffers for the current audio file. Only in rare cases
    /// will a frame buffer exceed the space requirement estimated by **prepareForFile()**.
    ///
    func prepareForBuffer(sampleCount: Int32) {
        
        // If the space required by the frame buffer's samples is greater than the already allocated space for output samples,
        // free the existing space and re-allocate space sufficient for this buffer's samples.
        if sampleCount > allocatedSampleCount {
         
            av_freep(&outputData[0])
            av_samples_alloc(outputData, nil, self.allocatedChannelCount, sampleCount, AV_SAMPLE_FMT_FLTP, 0)
        }
    }
    
    ///
    /// Deallocates any space previously allocated to hold the resampler's output samples.
    ///
    /// ```
    /// This function will typically be called exactly once, when playback of a file has ended.
    /// ```
    ///
    func deallocate() {
        av_freep(&outputData[0])
    }
    
    ///
    /// Resamples input samples from a frame buffer into the standard required sample format: 32-bit floating point non-interleaved (aka planar),
    /// and copies the output samples into the given audio buffer, starting at a given offset.
    ///
    /// - Parameter frame: A buffered frame whose samples need to be resampled.
    ///
    /// - Parameter audioBuffer: An audio buffer to which the output samples need to be copied.
    ///
    /// - Parameter offset: An offset used as the starting location in the audio buffer from which output samples will be copied.
    ///                     This should equal the number of samples previously copied into the audio buffer (from other frames).
    ///
    func resample(_ frame: BufferedFrame, copyTo audioBuffer: AVAudioPCMBuffer, withOffset offset: Int) {
        
        let sampleCount: Int32 = frame.sampleCount
        
        // Allocate the context used to perform the resampling.
        
        var resampleCtx: OpaquePointer? = swr_alloc()
        let resampleCtxPointer = UnsafeMutableRawPointer(resampleCtx)
        
        // Set the input / output channel layouts as options prior to resampling.
        // NOTE - Our output channel layout will be the same as that of the input, since we don't
        // need to do any upmixing / downmixing here.
        
        let channelLayout = frame.channelLayout > 0 ? Int64(frame.channelLayout) : Self.defaultChannelLayout
        av_opt_set_channel_layout(resampleCtxPointer, "in_channel_layout", channelLayout, 0)
        av_opt_set_channel_layout(resampleCtxPointer, "out_channel_layout", channelLayout, 0)
        
        // Set the input / output sample rates as options prior to resampling.
        // NOTE - Our output sample rate will be the same as that of the input, since we don't
        // need to do any upsampling / downsampling here.
        
        let sampleRate = Int64(frame.sampleRate)
        av_opt_set_int(resampleCtxPointer, "in_sample_rate", sampleRate, 0)
        av_opt_set_int(resampleCtxPointer, "out_sample_rate", sampleRate, 0)
        
        // Set the input / output sample formats as options prior to resampling.
        // NOTE - Our input sample format will be the format of the audio file being played,
        // and our output sample format will always be 32-bit floating point non-interleaved (aka planar).
        
        av_opt_set_sample_fmt(resampleCtxPointer, "in_sample_fmt", frame.sampleFormat.avFormat, 0)
        av_opt_set_sample_fmt(resampleCtxPointer, "out_sample_fmt", AV_SAMPLE_FMT_FLTP, 0)
        
        // Initialize the resampling context.
        swr_init(resampleCtx)
        
        // Perform the resampling.
        
        let outputDataPointer: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> = UnsafeMutableBufferPointer(start: outputData, count: frame.channelCount)
        
        // Access the input data as pointers from the frame being resampled.
        _ = frame.rawDataPointers.withMemoryRebound(to: UnsafePointer<UInt8>?.self) {
            (inputDataPointer: UnsafeMutableBufferPointer<UnsafePointer<UInt8>?>) in
            
            swr_convert(resampleCtx, outputDataPointer.baseAddress, sampleCount, inputDataPointer.baseAddress!, sampleCount)
        }

        // Resampling has been completed. Free the context.
        swr_free(&resampleCtx)
        
        // Finally, copy the output samples to the given audio buffer.
        copyOutputToAudioBuffer(frame, buffer: audioBuffer, withOffset: offset)
    }
    
    ///
    /// Copies resampling output samples into the given audio buffer, starting at a given offset.
    ///
    /// - Parameter frame: The buffered frame whose samples have been resampled.
    ///
    /// - Parameter audioBuffer: An audio buffer to which the output samples need to be copied.
    ///
    /// - Parameter offset: An offset used as the starting location in the audio buffer from which output samples will be copied.
    ///                     This should equal the number of samples previously copied into the audio buffer (from other frames).
    ///
    private func copyOutputToAudioBuffer(_ frame: BufferedFrame, buffer: AVAudioPCMBuffer, withOffset offset: Int) {
        
        let channels = buffer.floatChannelData
        let intSampleCount: Int = Int(frame.sampleCount)
        
        // Iterate through all the channels.
        for channelIndex in 0..<frame.channelCount {
            
            // Obtain pointers to the input and output data.
            guard let bytesForChannel = outputData[channelIndex], let channel = channels?[channelIndex] else {break}
            
            // Temporarily bind the output sample buffers as floating point numbers, and perform the copy.
            bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount) {
                (outputDataPointer: UnsafeMutablePointer<Float>) in
                
                // Use the Accelerate framework to perform the copy optimally.
                cblas_scopy(frame.sampleCount, outputDataPointer, 1, channel.advanced(by: offset), 1)
            }
        }
    }
}
