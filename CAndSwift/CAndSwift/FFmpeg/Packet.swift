import Foundation
import ffmpeg

class Packet {
    
    let pointer: UnsafeMutablePointer<AVPacket>
    var avPacket: AVPacket
    
    var streamIndex: Int32 {avPacket.stream_index}
    var size: Int32 {avPacket.size}
    var duration: Int64 {avPacket.duration}
    
    init() {
        
        self.avPacket = AVPacket()
        self.pointer = withUnsafeMutablePointer(to: &avPacket, {$0})
    }
    
    func destroy() {
        av_packet_unref(pointer)
    }
}
