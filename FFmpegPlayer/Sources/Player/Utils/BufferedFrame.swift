import AVFoundation
import Accelerate

///
/// A temporary container for the raw audio data from a single buffered frame.
///
class BufferedFrame: Hashable {
    
    ///
    /// Pointers to the raw data (unsigned bytes) constituting this frame's samples.
    ///
    var rawDataPointers: UnsafeMutableBufferPointer<UnsafeMutablePointer<UInt8>?>
    private var actualDataPointers: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>
    
    ///
    /// The number of pointers for which space has been allocated (and that need to be deallocated when this
    /// frame is destroyed).
    ///
    /// # Notes #
    ///
    /// 1. For interleaved (packed) samples, this value will always be 1, as data for all channels will be "packed" into a single buffer.
    ///
    /// 2. For non-interleaved (planar) samples, this value will always equal the channel count, as data for each channel will have its own "plane" (buffer).
    ///
    private var allocatedDataPointerCount: Int
    
    ///
    /// The channel layout for the samples contained in this frame.
    ///
    let channelLayout: UInt64
    
    ///
    /// The channel count for the samples contained in this frame.
    ///
    let channelCount: Int
    
    ///
    /// The number of samples contained in this frame.
    ///
    var sampleCount: Int32
    
    var firstSampleIndex: Int32
    
    ///
    /// The sampling rate for the samples contained in this frame, i.e. samples per second (or Hz).
    ///
    let sampleRate: Int32
    
    ///
    /// For interleaved (packed) samples, this value will equal the size in bytes of data for all channels.
    /// For non-interleaved (planar) samples, this value will equal the size in bytes of data for a single channel.
    ///
    let lineSize: Int
    
    ///
    /// The format of the samples contained in this frame.
    ///
    let sampleFormat: SampleFormat
    
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
    let timestamp: Int64
    
    let pts: Int64
    
    init(_ frame: Frame) {
        
        self.timestamp = frame.timestamp

        self.channelLayout = frame.channelLayout
        self.channelCount = Int(frame.channelCount)
        self.sampleCount = frame.sampleCount
        self.sampleRate = frame.sampleRate
        self.lineSize = frame.lineSize
        self.sampleFormat = frame.sampleFormat
        self.pts = frame.pts
        
        self.actualDataPointers = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: channelCount)
        self.allocatedDataPointerCount = 0
        
//        let sourceBuffers = frame.dataPointers
        
        // Copy over all the raw data from the source frame into this buffered frame.
        
        // Iterate through all the buffers in the source frame.
        
        // NOTE:
        // - For interleaved (packed) data, there will be only a single source buffer.
        // - For non-interleaved (planar) data, the number of source buffers will equal the channel count.
        
//        for bufferIndex in 0..<8 {
//
////            guard let sourceBuffer = sourceBuffers[bufferIndex] else {break}
//
//            // Allocate memory space equal to lineSize bytes, and initialize the data (copy) from the source buffer.
////            actualDataPointers[bufferIndex] = UnsafeMutablePointer<UInt8>.allocate(capacity: lineSize)
////            actualDataPointers[bufferIndex]?.initialize(from: sourceBuffer, count: lineSize)
//
//            allocatedDataPointerCount += 1
//        }
        
        self.rawDataPointers = UnsafeMutableBufferPointer(start: actualDataPointers, count: channelCount)
        self.firstSampleIndex = 0
    }
    
    func keepLastNSamples(sampleCount: Int32) {
        
        if sampleCount < self.sampleCount {
            
            firstSampleIndex = self.sampleCount - sampleCount
            self.sampleCount = sampleCount
        }
    }
    
    ///
    /// Copies this frame's samples to a given audio buffer starting at the given offset.
    ///
    /// - Parameter audioBuffer: The audio buffer to which this frame's samples are to be copied over.
    ///
    /// - Parameter offset:      A starting offset for each channel's data buffer in the audio buffer.
    ///                          This is required because the audio buffer may hold data from other
    ///                          frames copied to it previously. So, the offset will equal the sum of the
    ///                          the sample counts of all frames previously copied to the audio buffer.
    ///
    /// # Important #
    ///
    /// This function assumes that the format of the samples contained in this frame is: 32-bit floating-point planar,
    /// i.e. the samples do *not* require resampling.
    ///
    /// # Note #
    ///
    /// It is good from a safety perspective, to copy the frame's samples to the audio buffer right here rather than to give out a pointer to the memory
    /// space allocated from within this object so that a client object may perform the copy. This prevents any potentially unsafe use of the pointer.
    ///
    func copySamples(to audioBuffer: AVAudioPCMBuffer, startingAt offset: Int) {

        // Get pointers to 1 - this frame's raw data buffers, and 2 - the audio buffer's internal Float data buffers.
        guard let rawDataPointer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?> = rawDataPointers.baseAddress,
            let audioBufferChannels = audioBuffer.floatChannelData else {return}
        
        let intSampleCount: Int = Int(sampleCount)
        let intFirstSampleIndex: Int = Int(firstSampleIndex)
        
        for channelIndex in 0..<channelCount {
            
            // Get the pointers to the source and destination buffers for the copy operation.
            guard let bytesForChannel = rawDataPointer[channelIndex] else {break}
            let audioBufferChannel = audioBufferChannels[channelIndex]
            
            // Re-bind this frame's bytes to Float for the copy operation.
            _ = bytesForChannel.withMemoryRebound(to: Float.self, capacity: intSampleCount) {
                
                (floatsForChannel: UnsafeMutablePointer<Float>) in
                
                // Use Accelerate to perform the copy optimally, starting at the given offset.
                cblas_scopy(sampleCount, floatsForChannel.advanced(by: intFirstSampleIndex), 1, audioBufferChannel.advanced(by: offset), 1)
                
                if channelIndex == 0, firstSampleIndex != 0 {
                    print("\n\(sampleCount) samples copied from frame with PTS \(pts), firstIndex = \(firstSampleIndex)")
                }
            }
        }
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
        
        // Deallocate the memory space referenced by each of the data pointers.
        for index in 0..<allocatedDataPointerCount {
            self.actualDataPointers[index]?.deallocate()
        }
        
        // Deallocate the space occupied by the pointers themselves.
        self.actualDataPointers.deallocate()
        
        destroyed = true
    }
    
    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
    
    ///
    /// Equality comparison function (required by the Hashable protocol).
    ///
    /// Two BufferedFrame objects can be considered equal if and only if their timestamps are equal.
    ///
    /// # Important #
    ///
    /// This comparison makes the assumption that both frames originated from the same stream.
    /// Otherwise, this comparison is meaningless and invalid.
    ///
    static func == (lhs: BufferedFrame, rhs: BufferedFrame) -> Bool {
        lhs.timestamp == rhs.timestamp
    }
    
    ///
    /// Hash function (required by the Hashable protocol).
    ///
    /// Uses the timestamp to produce a hash value.
    ///
    func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
    }
}
