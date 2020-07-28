import Foundation

class Decoder {
    
    private var file: AudioFileContext!
    
    var eof: Bool = false
    
    private var format: FormatContext! {file.format}
    private var stream: AudioStream! {file.audioStream}
    private var codec: AudioCodec! {file.audioCodec}
    
    func initialize(with file: AudioFileContext) throws {
        
        self.file = file
        try codec.open()
        
        print("\nSuccessfully opened file: \(file.file.path). File is ready for decoding.")
        
        file.audioStream.printInfo()
        file.audioCodec.printInfo()
    }
    
    func decode(_ maxSampleCount: Int32) throws -> SamplesBuffer? {
        
        let buffer: SamplesBuffer = SamplesBuffer(sampleFormat: codec.sampleFormat, maxSampleCount: maxSampleCount)
        
        while !eof {
            
            do {
                
                let frame = try nextFrame()
                
                if buffer.appendFrame(frame: frame) {
                    _ = frameQueue.dequeue()
                    
                } else {    // Buffer is full, stop filling it.
                    break
                }
                
            } catch {
                
                // TODO: Possibility of infinite loop with continuous errors suppressed here.
                // Maybe set a maximum consecutive error limit ??? eg. If 3 consecutive errors are encountered, then break from the loop.
                if (error as? PacketReadError)?.isEOF ?? false {
                    self.eof = true
                }
            }
        }
        
        return buffer
    }
    
    func seekToTime(_ seconds: Double) throws {
        
        let seekPosRatio = seconds / stream.duration
        let targetFrame = Int64(seekPosRatio * Double(stream.frameCount))
        
        try format.seekWithinStream(stream, targetFrame)
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
}
