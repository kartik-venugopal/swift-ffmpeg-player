import Foundation

///
/// Assists in reading and decoding audio data from a codec.
/// Handles errors and signals special conditions such as end of file (EOF).
///
class Decoder {
    
    private var file: AudioFileContext!
    
    var eof: Bool = false
    
    private var format: FormatContext! {file.format}
    private var stream: AudioStream! {file.audioStream}
    private var codec: AudioCodec! {file.audioCodec}
    
    func initialize(with file: AudioFileContext) throws {
        
        self.file = file
        self.frameQueue.clear()
        self.eof = false
        
        try codec.open()
        
        file.audioStream.printInfo()
        file.audioCodec.printInfo()
    }
    
    func decode(_ maxSampleCount: Int32) throws -> SamplesBuffer {
        
        let buffer: SamplesBuffer = SamplesBuffer(sampleFormat: codec.sampleFormat, maxSampleCount: maxSampleCount)
        
        while !eof {
            
            do {
                
                let frame = try nextFrame()
                
                if buffer.appendFrame(frame: frame) {
                    _ = frameQueue.dequeue()
                    
                } else {    // Buffer is full, stop filling it.
                    break
                }
                
            } catch let packetReadError as PacketReadError {
                
                self.eof = packetReadError.isEOF
                if !eof {print("\nPacket read error:", packetReadError)}
                
            } catch let decError as DecoderError {
                print("\nDecoder error:", decError)
            }
        }
        
        // Once EOF has been reached, drain both:
        // - the frame queue (which may have overflow frames left over from the previous decoding loop), AND
        // - the codec's internal frame buffer
        //, and append them to our frame buffer.
        
        if eof {
            
            var terminalFrames: [BufferedFrame] = frameQueue.dequeueAll()
            
            do {
                
                let drainFrames = try codec.drain()
                terminalFrames.append(contentsOf: drainFrames)
                
            } catch {
                print("\nDecoder drain error:", error)
            }
            
            buffer.appendTerminalFrames(frames: terminalFrames)
        }
        
        return buffer
    }
    
    func seekToTime(_ seconds: Double) throws {
        
        do {
            
            try format.seekWithinStream(stream, seconds)
            self.eof = false
            
        } catch let seekError as SeekError {
            
            self.eof = seekError.isEOF
            if !eof {throw DecoderError(seekError.code)}
        }
    }
    
    private var frameQueue: Queue<BufferedFrame> = Queue<BufferedFrame>()
    
    private func nextFrame() throws -> BufferedFrame {
        
        while frameQueue.isEmpty {
        
            if let packet = try format.readPacket(stream) {
                
                for frame in try codec.decode(packet) {
                    frameQueue.enqueue(frame)
                }
            }
        }
        
        return frameQueue.peek()!
    }
    
    func stop() {
        frameQueue.clear()
    }
    
    func playbackCompleted() {
        self.file = nil
    }
}
