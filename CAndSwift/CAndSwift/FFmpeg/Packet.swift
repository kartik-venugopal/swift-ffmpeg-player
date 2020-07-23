import Foundation
import ffmpeg

class Packet {
    
    let pointer: UnsafeMutablePointer<AVPacket>
    let avPacket: AVPacket
    
    var streamIndex: Int32 {avPacket.stream_index}
    var size: Int32 {avPacket.size}
    var duration: Int64 {avPacket.duration}
    
    init() {
        
        self.pointer = av_packet_alloc()
        self.avPacket = pointer.pointee
    }
    
    func destroy() {
        av_packet_unref(pointer)
    }
}
