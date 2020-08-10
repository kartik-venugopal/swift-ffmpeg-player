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
    /// Singleton instance of this class that is shared by different client objects.
    ///
    static let instance = Resampler()
    
    ///
    /// The default channel layout to assume when the channel layout for an audio file cannot be determined.
    ///
    /// Should never have to be used.
    ///
    private static let defaultChannelLayout: Int64 = Int64(AV_CH_LAYOUT_STEREO)
    
    private static let standardSampleFormat: AVSampleFormat = AV_SAMPLE_FMT_FLTP
    
    ///
    /// Pointers to the memory space allocated for the resampler's output samples. Each pointer points to
    /// space allocated to samples for a single channel.
    ///
    var outputData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    
    ///
    /// Keeps track of the number of channels of output data for which memory space has been allocated.
    ///
    var allocatedChannelCount: Int32 = 0
    
    ///
    /// Keeps track of the number of samples (per channel) of output data for which memory space has been allocated.
    ///
    var allocatedSampleCount: Int32 = 0
    
    ///
    /// The initializer is made private so as to prevent clients from creating their own instances.
    /// Only one instance (i.e. a singleton) of this class should be created and made available
    /// as a static member.
    ///
    /// See **instance**.
    ///
    private init() {
        
        // Allocate space for up to 8 channels of sample data.
        outputData = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 8)
        outputData.initialize(to: nil)
    }
    
    ///
    /// Allocates enough memory space for a resampling conversion that produces output
    /// having a given channel count and sample count.
    ///
    /// - Parameter channelCount:   The number of channels to allocate space for (i.e. the number of output buffers).
    ///
    /// - Parameter sampleCount:   The number of output samples to allocate space for (i.e. the size of each output buffer).
    ///
    /// # Note #
    ///
    /// This function will only perform an allocation if the currently allocated space, if any, is
    /// not enough to accommodate output samples of the given channel and sample counts.
    /// If there is already enough space allocated, nothing will be done.
    ///
    func allocateFor(channelCount: Int32, sampleCount: Int32) {
        
        // Check if we already have enough allocated space for the given
        // channel count and sample count.
        if channelCount > allocatedChannelCount || sampleCount > allocatedSampleCount {
            
            // Not enough space already allocated. Need to re-allocate space.
            
            // First, deallocate any previously allocated space, if required.
            deallocate()
            
            // Allocate space.
            av_samples_alloc(outputData, nil, channelCount, sampleCount, AV_SAMPLE_FMT_FLTP, 0)
            
            // Update these variables to keep track of allocated space.
            self.allocatedChannelCount = channelCount
            self.allocatedSampleCount = sampleCount
        }
    }
    
    ///
    /// Deallocates any space previously allocated to hold the resampler's output samples.
    ///
    func deallocate() {
        
        if allocatedChannelCount > 0 && allocatedSampleCount > 0 {
            
            av_freep(&outputData[0])
            
            self.allocatedChannelCount = 0
            self.allocatedSampleCount = 0
        }
    }
    
    ///
    /// Resamples input samples from a frame buffer into the standard required sample format: 32-bit floating point non-interleaved (aka planar),
    /// and copies the output samples into the given audio buffer, starting at a given offset.
    ///
    /// - Parameter frame:          A buffered frame whose samples need to be resampled.
    ///
    /// - Parameter audioBuffer:    An audio buffer to which the output samples need to be copied once the resampling conversion is completed.
    ///
    /// - Parameter offset:         An offset used as the starting location in the audio buffer from which output samples will be copied.
    ///                             This should equal the number of samples previously copied into the audio buffer (from other frames).
    ///
    /// # Note #
    ///
    /// It is good from a safety perspective, to copy the output samples to the audio buffer right here rather than to give out a pointer to the memory
    /// space allocated from within this object so that a client object may perform the copy. This prevents any potentially unsafe use of the pointer.
    ///
    func resample(_ frame: Frame, andCopyOutputTo audioBuffer: AVAudioPCMBuffer, startingAt offset: Int) {
        
        // Allocate the context used to perform the resampling.
        guard let resampleCtx = ResamplingContext() else {
            
            print("\nUnable to instantiate resampling context !")
            return
        }
        
        // Set the input / output channel layouts as options prior to resampling.
        // NOTE - Our output channel layout will be the same as that of the input, since we don't
        // need to do any upmixing / downmixing here.
        
        let channelLayout = frame.channelLayout > 0 ? Int64(frame.channelLayout) : Self.defaultChannelLayout
        resampleCtx.inputChannelLayout = channelLayout
        resampleCtx.outputChannelLayout = channelLayout
        
        // Set the input / output sample rates as options prior to resampling.
        // NOTE - Our output sample rate will be the same as that of the input, since we don't
        // need to do any upsampling / downsampling here.
        
        let sampleRate = Int64(frame.sampleRate)
        resampleCtx.inputSampleRate = sampleRate
        resampleCtx.outputSampleRate = sampleRate
        
        // Set the input / output sample formats as options prior to resampling.
        // NOTE - Our input sample format will be the format of the audio file being played,
        // and our output sample format will always be 32-bit floating point non-interleaved (aka planar).
        
        resampleCtx.inputSampleFormat = frame.sampleFormat.avFormat
        resampleCtx.outputSampleFormat = Self.standardSampleFormat
        
        // Perform the resampling.
        
        let outputDataPointer: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?> = UnsafeMutableBufferPointer(start: outputData, count: Int(frame.channelCount))
        
        let sampleCount: Int32 = frame.sampleCount
        
        // Access the input data as pointers from the frame being resampled.
        _ = frame.rawDataPointers.withMemoryRebound(to: UnsafePointer<UInt8>?.self) {
            (inputDataPointer: UnsafeMutableBufferPointer<UnsafePointer<UInt8>?>) in
            
            resampleCtx.convert(inputDataPointer: inputDataPointer.baseAddress,
                                inputSampleCount: sampleCount,
                                outputDataPointer: outputDataPointer.baseAddress!,
                                outputSampleCount: sampleCount)
        }
        
        // Finally, copy the output samples to the given audio buffer.
        copyOutputFor(frame: frame, to: audioBuffer, startingAt: offset)
    }
    
    ///
    /// Copies resampling output samples for a given frame into the given audio buffer, starting at a given offset.
    ///
    /// - Parameter frame:       The buffered frame whose samples have been resampled.
    ///
    /// - Parameter audioBuffer: An audio buffer to which the output samples need to be copied.
    ///
    /// - Parameter offset:      A starting offset for each channel's data buffer in the audio buffer.
    ///                          This is required because the audio buffer may hold data from other
    ///                          frames copied to it previously. So, the offset will equal the sum of the
    ///                          the sample counts of all frames previously copied to the audio buffer.
    ///
    private func copyOutputFor(frame: Frame, to audioBuffer: AVAudioPCMBuffer, startingAt offset: Int) {
        
        // Get a pointer to the audio buffer's internal data buffer.
        guard let audioBufferChannels = audioBuffer.floatChannelData else {return}
        
        let intSampleCount: Int = Int(frame.sampleCount)
//        let intFirstSampleIndex: Int = Int(frame.firstSampleIndex)
        
        // Iterate through all the channels.
        for channelIndex in 0..<Int(frame.channelCount) {
            
            // Obtain pointers to the input and output data.
            guard let bytesForChannel = outputData[channelIndex] else {break}
            let audioBufferChannel = audioBufferChannels[channelIndex]
            
            // Temporarily bind the output sample buffers as floating point numbers, and perform the copy.
            bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount) {
                (outputDataPointer: UnsafeMutablePointer<Float>) in
                
                // Use Accelerate to perform the copy optimally, starting at the given offset.
                cblas_scopy(frame.sampleCount, outputDataPointer.advanced(by: 0), 1, audioBufferChannel.advanced(by: offset), 1)
                
//                if channelIndex == 0, intFirstSampleIndex != 0 {
//                    print("\n\(intSampleCount) samples copied from frame with PTS \(frame.pts), firstIndex = \(intFirstSampleIndex)")
//                }
            }
        }
    }
}
