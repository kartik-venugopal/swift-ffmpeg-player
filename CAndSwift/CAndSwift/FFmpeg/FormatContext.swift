import Foundation
import ffmpeg

class FormatContext {

    let file: URL
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    let avContext: AVFormatContext
    
    var streams: [Stream]
    
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
        
        let resultCode: Int32 = avformat_find_stream_info(pointer, nil)
        if resultCode < 0 {
            
            print("\nFormatContext.init(): Unable to find stream info for file '\(filePath)'. Error: \(errorString(errorCode: resultCode))")
            return nil
        }
        
        self.streams = []
        
        if let streams = avContext.streams {
        
            let avStreamPointers: [UnsafeMutablePointer<AVStream>] = (0..<avContext.nb_streams).compactMap {streams.advanced(by: Int($0)).pointee}
            
            self.streams = avStreamPointers.compactMap {pointer in
                
                switch pointer.pointee.codecpar.pointee.codec_type {
                    
                case AVMEDIA_TYPE_AUDIO:    return AudioStream(pointer)
                    
                case AVMEDIA_TYPE_VIDEO:    return ImageStream(pointer)
                    
                default:                    return nil
                    
                }
            }
        }
    }
    
    var audioStream: AudioStream? {
        streams.compactMap {$0 as? AudioStream}.first
    }
    
    var imageStream: ImageStream? {
        streams.compactMap {$0 as? ImageStream}.first
    }
    
    func readPacket(_ stream: Stream) throws -> Packet? {
        
        let packet = Packet()

        let readResult: Int32 = av_read_frame(pointer, packet.pointer)
        guard readResult >= 0 else {
            
            print("\nFormatContext.readPacket(): Unable to read packet. Error: \(readResult) (\(errorString(errorCode: readResult)))")
            throw PacketReadError(readResult)
        }
        
        return packet.streamIndex == stream.index ? packet : nil
    }

    func destroy() {
        
        avformat_close_input(&pointer)
        avformat_free_context(pointer)
    }
}
