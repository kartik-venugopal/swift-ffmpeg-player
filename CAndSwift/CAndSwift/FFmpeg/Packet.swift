import Foundation

class Packet {
    
    var avPacket: AVPacket
    
    var streamIndex: Int32 {avPacket.stream_index}
    var size: Int32 {avPacket.size}
    var duration: Int64 {avPacket.duration}
    
    init(_ formatCtx: UnsafeMutablePointer<AVFormatContext>?) throws {
        
        self.avPacket = AVPacket()
        let readResult: Int32 = av_read_frame(formatCtx, &avPacket)
        guard readResult >= 0 else {
            
            print("\nPacket.init(): Unable to read packet. Error: \(readResult) (\(readResult.errorDescription)))")
            throw PacketReadError(readResult)
        }
    }
    
    func readFrom(_ formatCtx: UnsafeMutablePointer<AVFormatContext>?) -> ResultCode {
        return av_read_frame(formatCtx, &avPacket)
    }
    
    func sendTo(_ codec: Codec) -> ResultCode {
        return avcodec_send_packet(codec.contextPointer, &avPacket)
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}
        av_packet_unref(&avPacket)
        destroyed = true
    }
    
    deinit {
        destroy()
    }
}
