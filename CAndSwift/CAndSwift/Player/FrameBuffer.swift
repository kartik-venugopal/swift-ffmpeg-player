import AVFoundation
import Accelerate

///
/// A temporary container that accumulates / buffers frames until the number of frames
/// is deemed large enough to schedule for playback.
///
/// Also assists in constructing AVAudioPCMBuffer objects that can be scheduled for playback.
///
class FrameBuffer {
    
    ///
    /// An ordered list of buffered frames. The ordering is important as it reflects the order of
    /// the corresponding samples in the audio file from which they were read.
    ///
    private var frames: [BufferedFrame] = []
    
    ///
    /// The PCM format of the samples in this buffer.
    ///
    private let sampleFormat: SampleFormat
    
    ///
    /// A counter that keeps track of how many samples have been accumulated in this buffer.
    /// i.e. the sum of the sample counts of each of the buffered frames.
    ///
    /// ```
    /// It is updated as individual frames are appended to this buffer.
    /// ```
    ///
    private var sampleCount: Int32 = 0
    
    ///
    /// A limit on the number of samples to be accumulated.
    ///
    /// ```
    /// It is set exactly once when this buffer is instantiated.
    /// ```
    ///
    private let maxSampleCount: Int32
    
    init(sampleFormat: SampleFormat, maxSampleCount: Int32) {
        
        self.sampleFormat = sampleFormat
        self.maxSampleCount = maxSampleCount
    }
    
    ///
    /// Attempts to append a single frame to this buffer. Succeeds if this buffer can accommodate the
    /// samples of the new frame, limited by **maxSampleCount**.
    ///
    /// - Parameter frame: The new frame to append to this buffer.
    ///
    /// - returns: Whether or not the frame was successfully appended to the buffer.
    ///
    func appendFrame(frame: BufferedFrame) -> Bool {

        // Check if the sample count of the new frame would cause this buffer to
        // exceed maxSampleCount.
        if self.sampleCount + frame.sampleCount <= maxSampleCount {
            
            // Update the sample count, and append the frame.
            self.sampleCount += frame.sampleCount
            frames.append(frame)
            
            return true
        }
        
        // Buffer cannot accommodate the new frame. It is "full".
        return false
    }
    
    ///
    /// Appends an array of "terminal" frames that constitute the last few frames in an audio stream.
    ///
    /// - Parameter frames: The terminal frames to append to this buffer.
    ///
    /// # Notes #
    ///
    /// Terminal frames are not subject to the **maxSampleCount** limit.
    ///
    /// So, unlike **appendFrame()**, this function will not reject the terminal frames ... they will always
    /// be appended to this buffer.
    ///
    func appendTerminalFrames(frames: [BufferedFrame]) {
        
        for frame in frames {
            
            self.sampleCount += frame.sampleCount
            self.frames.append(frame)
        }
    }
    
    ///
    /// Constructs an audio buffer from the samples in this buffer's frames.
    /// The returned audio buffer can be scheduled for playback by the audio engine.
    ///
    /// - Parameter format: The format of the audio buffer that is to be constructed.
    ///
    /// - returns:  The newly constructed audio buffer. Nil if this buffer contains no samples or
    ///             if an invalid audio format has been specified.
    ///
    /// # Notes #
    ///
    /// If required, the contained samples will be resampled before being copied to the
    /// audio buffer.
    ///
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        
        guard sampleCount > 0 else {return nil}
        
        // Command the resampler to allocate enough space to accommodate the
        // output of resampling this buffer's samples.
        if sampleFormat.needsResampling {
            Resampler.instance.prepareForBuffer(sampleCount: self.sampleCount)
        }
        
        if let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            // The audio buffer will be filled to capacity
            audioBuffer.frameLength = audioBuffer.frameCapacity

            // Get a pointer to the audio buffer's internal data buffer.
            let audioBufferChannels = audioBuffer.floatChannelData
            
            // Keep track of how many samples have been copied over so far.
            // This will be used as an offset when performing the copy.
            var sampleCountSoFar: Int = 0
            
            for frame in frames {
                
                // Resample the frame's samples if required.
                if sampleFormat.needsResampling {
                    
                    Resampler.instance.resample(frame, copyTo: audioBuffer, withOffset: sampleCountSoFar)
                    
                } else {
                    
                    // Copy over the frame's samples to the audio buffer (no resampling required).
                    
                    let frameFloats: [UnsafePointer<Float>] = frame.playableFloatPointers
                    
                    // Iterate through all the channels.
                    for channelIndex in 0..<frameFloats.count {
                        
                        guard let channel = audioBufferChannels?[channelIndex] else {break}
                        let frameFloatsForChannel = frameFloats[channelIndex]
                    
                        // Use Accelerate to perform the copy, starting at an offset equal to the number of samples copied over so far.
                        cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: sampleCountSoFar), 1)
                    }
                }
                
                // Update the counter.
                sampleCountSoFar += Int(frame.sampleCount)
            }
            
            return audioBuffer
        }
        
        return nil
    }
    
    /// Indicates whether or not this object has already been destroyed.
    private var destroyed: Bool = false
    
    ///
    /// Performs cleanup (deallocation of allocated memory space) when
    /// this object is about to be deinitialized.
    ///
    func destroy() {
        
        // This check ensures that the deallocation happens
        // only once. Otherwise, a fatal error will be
        // thrown.
        if destroyed {return}
        
        // Destroy each of the individual frames.
        frames.forEach {$0.destroy()}
        
        destroyed = true
    }
    
    deinit {
        destroy()
    }
}
