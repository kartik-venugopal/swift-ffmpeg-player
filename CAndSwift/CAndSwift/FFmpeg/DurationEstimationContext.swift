import Foundation

// A utility that calculates the duration of an audio track by brute force,
// i.e. reading all packets. This method of duration computation should
// be used as the last resort when all other methods have failed.
class DurationEstimationContext {
    
    let file: URL
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    var avContext: AVFormatContext {pointer!.pointee}
    
    var duration: Double = 0
    
    init?(_ file: URL) {
        
        self.file = file
        self.pointer = avformat_alloc_context()
        
        var resultCode: ResultCode = avformat_open_input(&pointer, file.path, nil, nil)
        guard resultCode.isNonNegative, pointer?.pointee != nil else {
            return nil
        }
        
        resultCode = avformat_find_stream_info(pointer, nil)
        guard resultCode.isNonNegative else {
            return nil
        }
        
        var audioStreamIndex: Int = -1
        var timeBase: AVRational?
        
        if let avStreams = avContext.streams {
        
            for streamIndex in 0..<Int(avContext.nb_streams) {
                
                if let avStreamPointer: UnsafeMutablePointer<AVStream> = avStreams.advanced(by: streamIndex).pointee,
                    avStreamPointer.pointee.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
                    
                    audioStreamIndex = streamIndex
                    timeBase = avStreamPointer.pointee.time_base
                    break
                }
            }
        }
        
        guard audioStreamIndex >= 0, let theTimeBase = timeBase else {return nil}
        
        var lastPacket: Packet!
        
        do {
            
            while true {
                
                let packet = try Packet(pointer)
                if packet.streamIndex == audioStreamIndex {
                    lastPacket = packet
                }
            }
            
        } catch {
            
            if (error as? CodedError)?.isEOF ?? false, let theLastPacket = lastPacket {
                self.duration = Double(theLastPacket.pts + theLastPacket.duration) * theTimeBase.ratio
            }
        }
    }
}
