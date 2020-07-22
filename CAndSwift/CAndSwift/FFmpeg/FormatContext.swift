import Foundation
import ffmpeg

class FormatContext {

    let file: URL
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    let avContext: AVFormatContext
    
    init?(_ file: URL) {
        
        self.file = file
        self.filePath = file.path
        
        self.pointer = avformat_alloc_context()
        
        let fileOpenResult: Int32 = avformat_open_input(&pointer, file.path, nil, nil)
        
        if fileOpenResult >= 0, let pointee = pointer?.pointee {
            self.avContext = pointee
            
        } else {
            
            print("\nFormatContext.init(): Unable to open file '\(filePath)'. Error: \(errorString(errorCode: fileOpenResult))")
            return nil
        }
    }
    
    func readPacket(_ stream: Stream) throws -> Packet? {
        
        var packet = AVPacket()

        let readResult: Int32 = av_read_frame(pointer, &packet)
        guard readResult >= 0 else {
            
            print("\nFormatContext.readPacket(): Unable to read packet. Error: \(readResult) (\(errorString(errorCode: readResult)))")
            throw PacketReadError(readResult)
        }
        
        return packet.stream_index == stream.index ? Packet(&packet) : nil
    }
    
    func destroy() {
        
        avformat_close_input(&pointer)
        avformat_free_context(pointer)
    }
}
