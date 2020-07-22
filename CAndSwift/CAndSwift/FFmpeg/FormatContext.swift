import Foundation
import ffmpeg

class FormatContext {

    let file: URL
    let path: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    let avContext: AVFormatContext
    
    init?(_ file: URL) {
        
        self.file = file
        self.path = file.path
        
        self.pointer = avformat_alloc_context()
        
        if avformat_open_input(&pointer, file.path, nil, nil) >= 0, let pointee = pointer?.pointee {
            self.avContext = pointee
        } else {
            return nil
        }
    }
    
    func readPacket(_ stream: Stream) throws -> Packet? {
        
        var packet = AVPacket()

        guard av_read_frame(pointer, &packet) > 0 else {throw EOFError()}
        
        return packet.stream_index == stream.index ? Packet(&packet) : nil
    }
}
