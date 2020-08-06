import Foundation

///
/// Encapsulates an ffmpeg AVFrame struct that represents a single (decoded) frame,
/// i.e. audio data in its raw decoded / uncompressed form, post-decoding,
/// and provides convenient Swift-style access to its functions and member variables.
///
class Frame {
 
    ///
    /// The encapsulated AVFrame object.
    ///
    var avFrame: AVFrame
    
    ///
    /// Describes the number and physical / spatial arrangement of the channels. (e.g. "5.1 surround" or "stereo")
    ///
    var channelLayout: UInt64 {avFrame.channel_layout}
    
    ///
    /// Number of channels of audio data.
    ///
    var channelCount: Int32 {avFrame.channels}

    ///
    /// PCM format of the samples.
    ///
    var sampleFormat: SampleFormat
    
    ///
    /// Total number of samples in this frame.
    ///
    var sampleCount: Int32 {avFrame.nb_samples}
    
    ///
    /// Whether or not this frame has any samples.
    ///
    var hasSamples: Bool {avFrame.nb_samples.isPositive}
    
    ///
    /// Sample rate of the decoded data (i.e. number of samples per second or Hz).
    ///
    var sampleRate: Int32 {avFrame.sample_rate}
    
    ///
    /// For interleaved (packed) samples, this value will equal the size in bytes of data for all channels.
    /// For non-interleaved (planar) samples, this value will equal the size in bytes of data for a single channel.
    ///
    var lineSize: Int {Int(avFrame.linesize.0)}
    
    ///
    /// A timestamp indicating this frame's position (order) within the parent audio stream,
    /// specified in stream time base units.
    ///
    /// ```
    /// This can be useful when using concurrency to decode multiple
    /// packets simultaneously. The received frames, in that case,
    /// would be in arbitrary order, and this timestamp can be used
    /// to sort them in the proper presentation order.
    /// ```
    ///
    var timestamp: Int64 {avFrame.best_effort_timestamp}
    
    ///
    /// Pointers to the raw data (unsigned bytes) constituting this frame's samples.
    ///
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {avFrame.dataPointers}
    
    ///
    /// Instantiates a Frame and sets the sample format.
    ///
    /// - Parameter sampleFormat: The format of the samples in this frame.
    ///
    init(sampleFormat: SampleFormat) {
        
        self.avFrame = AVFrame()
        self.sampleFormat = sampleFormat
    }
    
    ///
    /// Receives a decoded frame from a codec.
    ///
    /// - Parameter codec: The codec that will produce a decoded frame.
    ///
    /// - returns: An integer code indicating the result of the receive operation.
    ///
    func receiveFrom(_ codec: Codec) -> ResultCode {
        return avcodec_receive_frame(codec.contextPointer, &avFrame)
    }
    
    ///
    /// Unreference all data buffers referenced by the underlying AVFrame.
    ///
    func unreferenceBuffers() {
        av_frame_unref(&avFrame)
    }
    
    /// Indicates whether or not this object has already been destroyed.
    private var destroyed: Bool = false
    
    ///
    /// Performs cleanup (deallocation of allocated memory space) when
    /// this object is about to be deinitialized or is no longer needed.
    ///
    func destroy() {

        // This check ensures that the deallocation happens
        // only once. Otherwise, a fatal error will be
        // thrown.
        if destroyed {return}
        
        // Free up the space allocated to this frame.
        av_frame_unref(&avFrame)
        av_freep(&avFrame)
        
        destroyed = true
    }
    
    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}

extension AVFrame {

    ///
    /// An array of pointers to the raw data contained in this AVFrame.
    ///
    var dataPointers: [UnsafeMutablePointer<UInt8>?] {
        Array(UnsafeBufferPointer(start: self.extended_data, count: 8)) // Access up to 8 channels of samples.
    }
}
