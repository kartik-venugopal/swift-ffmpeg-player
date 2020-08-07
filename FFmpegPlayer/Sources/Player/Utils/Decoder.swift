import Foundation

///
/// Assists in reading and decoding audio data from a codec.
/// Handles errors and signals special conditions such as end of file (EOF).
///
class Decoder {
    
    /// A context associated with the currently playing file.
    private var file: AudioFileContext!
    
    ///
    /// The context used to read packets and perform seeking within the audio stream.
    ///
    private var format: FormatContext! {file.format}
    
    ///
    /// The audio stream that is to be decoded.
    ///
    private var stream: AudioStream! {file.audioStream}
    
    ///
    /// The codec that will actually do the decoding.
    ///
    private var codec: AudioCodec! {file.audioCodec}
    
    ///
    /// A flag indicating whether or not the codec has reached the end of the currently playing file's audio stream, i.e. EOF..
    ///
    var eof: Bool = false
    
    ///
    /// A queue data structure used to temporarily hold buffered frames as they are decoded by the codec and before passing them off to a FrameBuffer.
    ///
    /// # Notes #
    ///
    /// During a decoding loop, in the event that a FrameBuffer fills up, this queue will hold the overflow (excess) frames that can be passed off to the next
    /// FrameBuffer in the next decoding loop.
    ///
    private var frameQueue: Queue<BufferedFrame> = Queue<BufferedFrame>()
    
    ///
    /// Prepares the codec to decode a given audio file.
    ///
    /// ```
    /// This function will be called exactly once when a file is chosen for immediate playback.
    /// ```
    ///
    /// - Parameter file: A context through which decoding of the audio file can be performed.
    ///
    /// - throws: A **DecoderInitializationError** if the underlying codec cannot be opened.
    ///
    func initialize(with file: AudioFileContext) throws {
        
        self.file = file
        
        // Clear any residual (previously queued) frames from the queue.
        self.frameQueue.clear()
        
        // Reset the EOF flag.
        self.eof = false
        
        // Try opening the codec. This step is vital to being able to decode this file.
        try codec.open()
        
        // Dump some stream / codec info to the log/console as an indication of successfully opening the codec.
        file.audioStream.printInfo()
        file.audioCodec.printInfo()
    }
    
    ///
    /// Decodes the currently playing file's audio stream to produce a given (maximum) number of samples, in a loop, and returns a frame buffer
    /// containing all the samples produced during the loop.
    ///
    /// # Notes #
    ///
    /// 1. If the codec reaches EOF during the loop, the number of samples produced may be less than the maximum sample count specified by
    /// the **maxSampleCount** parameter. However, in rare cases, the actual number of samples may be slightly larger than the maximum,
    /// because upon reaching EOF, the decoder will drain the codec's internal buffers which may result in a few additional samples that will be
    /// allowed as this is the terminal buffer.
    ///
    func decode(maxSampleCount: Int32) -> FrameBuffer {
        
        // Create a frame buffer with the specified maximum sample count and the codec's sample format for this file.
        let buffer: FrameBuffer = FrameBuffer(sampleFormat: codec.sampleFormat, maxSampleCount: maxSampleCount)
        
        // Keep decoding as long as EOF is not reached.
        while !eof {
            
            do {

                // Try to obtain a single decoded frame.
                let frame = try nextFrame()
                
                // Try appending the frame to the frame buffer.
                // The frame buffer may reject the new frame if appending it would
                // cause its sample count to exceed the maximum.
                if buffer.appendFrame(frame: frame) {
                    
                    // The buffer accepted the new frame. Remove it from the queue.
                    _ = frameQueue.dequeue()
                    
                } else {
                    
                    // The frame buffer rejected the new frame because it is full. End the loop.
                    break
                }
                
            } catch let packetReadError as PacketReadError {
                
                // If the error signals EOF, suppress it, and simply set the EOF flag.
                self.eof = packetReadError.isEOF
                
                // If the error is something other than EOF, it either indicates a real problem or simply that there was one bad packet. Log the error.
                if !eof {print("\nPacket read error:", packetReadError)}
                
            } catch {
                
                // This either indicates a real problem or simply that there was one bad packet. Log the error.
                print("\nDecoder error:", error)
            }
        }
        
        // If and when EOF has been reached, drain both:
        //
        // - the frame queue (which may have overflow frames left over from the previous decoding loop), AND
        // - the codec's internal frame buffer
        //
        //, and append them to our frame buffer.
        
        if eof {
            
            var terminalFrames: [BufferedFrame] = frameQueue.dequeueAll()
            
            do {
                
                let drainFrames = try codec.drain()
                terminalFrames.append(contentsOf: drainFrames)
                
            } catch {
                print("\nDecoder drain error:", error)
            }
          
            // Append these terminal frames to the frame buffer (the frame buffer cannot reject terminal frames).
            buffer.appendTerminalFrames(frames: terminalFrames)
        }
        
        return buffer
    }
    
    ///
    /// Seeks to a given position within the currently playing file's audio stream.
    ///
    /// - Parameter time: A desired seek position, specified in seconds. Must be greater than 0.
    ///
    /// - throws: A **SeekError** if the seek fails *and* EOF has *not* been reached.
    ///
    /// # Notes #
    ///
    /// 1. If the seek goes past the end of the currently playing file, i.e. **time** > stream duration, the EOF flag will be set.
    ///
    /// 2. If the EOF flag had previously been set (true), but this seek took the stream to a position before EOF,
    /// the EOF flag will be reset (false) by this function call.
    ///
    func seek(to time: Double) throws {
        
        do {
            
            try format.seek(within: stream, to: time)
            
            // If the seek succeeds, we have not reached EOF.
            self.eof = false
            
        } catch let seekError as SeekError {
            
            // EOF is considered harmless, only throw if another type of error occurred.
            self.eof = seekError.isEOF
            if !eof {throw DecoderError(seekError.code)}
        }
    }
    
    ///
    /// Decodes the next available packet in the stream, if required, to produce a single frame.
    ///
    /// - returns:  A single frame containing PCM samples.
    ///
    /// - throws:   A **PacketReadError** if the next packet in the stream cannot be read, OR
    ///             A **DecoderError** if a packet was read but unable to be decoded by the codec.
    ///
    /// # Notes #
    ///
    /// 1. If there are already frames in the frame queue, that were produced by a previous call to this function, no
    /// packets will be read / decoded. The first frame from the queue will simply be returned.
    ///
    /// 2. If more than one frame is produced by the decoding of a packet, the first such frame will be returned, and any
    /// excess frames will remain in the frame queue to be consumed by the next call to this function.
    ///
    /// 3. The returned frame will not be dequeued (removed from the queue) by this function. It is the responsibility of the caller
    /// to do so, upon consuming the frame.
    ///
    private func nextFrame() throws -> BufferedFrame {
        
        while frameQueue.isEmpty {
        
            if let packet = try format.readPacket(from: stream) {
                
                for frame in try codec.decode(packet) {
                    frameQueue.enqueue(frame)
                }
            }
        }
        
        return frameQueue.peek()!
    }
    
    ///
    /// Responds to playback for a file being stopped, by performing any necessary cleanup.
    ///
    func stop() {
        frameQueue.clear()
    }
    
    ///
    /// Responds to completion of playback for a file, by performing any necessary cleanup.
    ///
    func playbackCompleted() {
        self.file = nil
    }
}
