import Foundation

///
/// A wrapper around an ffmpeg SwrContext that performs a resampling conversion:
///
/// A resampling conversion could consist of any or all of the following:
/// 
/// - Conversion of channel layout (re-matrixing)
/// - Conversion of sample rate (upsampling / downsampling)
/// - Conversion of sample format
///
/// # Notes #
///
/// - Instantiates a resampling context (SwrContext).
/// - Sets resampling options.
/// - Performs the actual resampling.
///
/// # Important #
///
/// This object does *not* allocate space for input / output samples. It is the caller's responsibility to do so
/// before invoking **convert()**.
///
class ResamplingContext {

    ///
    /// Pointer to the encapsulated SwrContext struct.
    ///
    private var resampleCtx: OpaquePointer?
    
    ///
    /// An UnsafeMutableRawPointer to **resampleCtx**.
    ///
    private let resampleCtxPointer: UnsafeMutableRawPointer?
    
    ///
    /// Tries to allocate a resampling context. Returns nil if the allocation fails.
    ///
    init?() {
        
        guard let context = swr_alloc() else {return nil}
        
        self.resampleCtx = context
        self.resampleCtxPointer = UnsafeMutableRawPointer(resampleCtx)
    }
    
    ///
    /// The channel layout of the input samples.
    ///
    var inputChannelLayout: Int64? {
        
        didSet {
            
            if let channelLayout = inputChannelLayout {
                av_opt_set_channel_layout(resampleCtxPointer, "in_channel_layout", channelLayout, 0)
            }
        }
    }
    
    ///
    /// The (desired) channel layout of the output samples.
    ///
    var outputChannelLayout: Int64? {
        
        didSet {
            
            if let channelLayout = outputChannelLayout {
                av_opt_set_channel_layout(resampleCtxPointer, "out_channel_layout", channelLayout, 0)
            }
        }
    }
    
    ///
    /// The sample rate of the input samples.
    ///
    var inputSampleRate: Int64? {
        
        didSet {
            
            if let sampleRate = inputSampleRate {
                av_opt_set_int(resampleCtxPointer, "in_sample_rate", sampleRate, 0)
            }
        }
    }
    
    ///
    /// The (desired) sample rate of the output samples.
    ///
    var outputSampleRate: Int64? {
        
        didSet {
            
            if let sampleRate = outputSampleRate {
                av_opt_set_int(resampleCtxPointer, "out_sample_rate", sampleRate, 0)
            }
        }
    }
    
    ///
    /// The sample format of the input samples.
    ///
    var inputSampleFormat: AVSampleFormat? {
        
        didSet {
            
            if let sampleFormat = inputSampleFormat {
                av_opt_set_sample_fmt(resampleCtxPointer, "in_sample_fmt", sampleFormat, 0)
            }
        }
    }
    
    ///
    /// The (desired) sample format of the output samples.
    ///
    var outputSampleFormat: AVSampleFormat? {
        
        didSet {
            
            if let sampleFormat = outputSampleFormat {
                av_opt_set_sample_fmt(resampleCtxPointer, "out_sample_fmt", sampleFormat, 0)
            }
        }
    }
    
    ///
    /// Performs the resampling conversion.
    ///
    /// - Parameter inputDataPointer: Pointer to the input data (as bytes).
    ///
    /// - Parameter inputSampleCount: The number of input samples (per channel).
    ///
    /// - Parameter outputDataPointer: Pointer to the allocated space for the output data (as bytes).
    ///
    /// - Parameter outputSampleCount: The number of (desired) output samples (per channel).
    ///
    func convert(inputDataPointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>?,
                 inputSampleCount: Int32,
                 outputDataPointer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                 outputSampleCount: Int32) {

        // Need to initialize the context before the conversion can be performed.
        swr_init(resampleCtx)
        swr_convert(resampleCtx, outputDataPointer, outputSampleCount, inputDataPointer, inputSampleCount)
    }

    /// Frees the context.
    deinit {
        swr_free(&resampleCtx)
    }
}
