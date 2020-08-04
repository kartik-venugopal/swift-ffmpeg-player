import Foundation

class ResamplingContext {
    
    private var resampleCtx: OpaquePointer?
    private let resampleCtxPointer: UnsafeMutableRawPointer?
    
    init?() {
        
        guard let context = swr_alloc() else {return nil}
        
        self.resampleCtx = context
        self.resampleCtxPointer = UnsafeMutableRawPointer(resampleCtx)
    }
    
    var inputChannelLayout: Int64? {
        
        didSet {
            
            if let channelLayout = inputChannelLayout {
                av_opt_set_channel_layout(resampleCtxPointer, "in_channel_layout", channelLayout, 0)
            }
        }
    }
    
    var outputChannelLayout: Int64? {
        
        didSet {
            
            if let channelLayout = outputChannelLayout {
                av_opt_set_channel_layout(resampleCtxPointer, "out_channel_layout", channelLayout, 0)
            }
        }
    }
    
    var inputSampleRate: Int64? {
        
        didSet {
            
            if let sampleRate = inputSampleRate {
                av_opt_set_int(resampleCtxPointer, "in_sample_rate", sampleRate, 0)
            }
        }
    }
    
    var outputSampleRate: Int64? {
        
        didSet {
            
            if let sampleRate = outputSampleRate {
                av_opt_set_int(resampleCtxPointer, "out_sample_rate", sampleRate, 0)
            }
        }
    }
    
    var inputSampleFormat: AVSampleFormat? {
        
        didSet {
            
            if let sampleFormat = inputSampleFormat {
                av_opt_set_sample_fmt(resampleCtxPointer, "in_sample_fmt", sampleFormat, 0)
            }
        }
    }
    
    var outputSampleFormat: AVSampleFormat? {
        
        didSet {
            
            if let sampleFormat = outputSampleFormat {
                av_opt_set_sample_fmt(resampleCtxPointer, "out_sample_fmt", sampleFormat, 0)
            }
        }
    }
    
    func convert(inputDataPointer: UnsafeMutablePointer<UnsafePointer<UInt8>?>?,
                 inputSampleCount: Int32,
                 outputDataPointer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
                 outputSampleCount: Int32) {

        // Need to initialize the context before the conversion can be performed.
        swr_init(resampleCtx)
        swr_convert(resampleCtx, outputDataPointer, outputSampleCount, inputDataPointer, inputSampleCount)
    }

    // Free the context.
    deinit {
        swr_free(&resampleCtx)
    }
}
