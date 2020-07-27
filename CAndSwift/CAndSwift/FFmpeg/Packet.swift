import Foundation

class Packet {
    
    var avPacket: AVPacket
    
    var streamIndex: Int32 {avPacket.stream_index}
    var size: Int32 {avPacket.size}
    var duration: Int64 {avPacket.duration}
    
    init() {
        self.avPacket = AVPacket()
    }
    
    func destroy() {
        av_packet_unref(&avPacket)
    }
    
    func readFrom(_ formatCtx: UnsafeMutablePointer<AVFormatContext>?) -> ResultCode {
        return av_read_frame(formatCtx, &avPacket)
    }
    
    func sendTo(_ codecCtx: UnsafeMutablePointer<AVCodecContext>?) -> ResultCode {
        return avcodec_send_packet(codecCtx, &avPacket)
    }
}
