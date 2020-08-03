import Foundation

// A utility that calculates the duration of an audio track by brute force,
// i.e. reading all packets. This method of duration computation should
// be used as the last resort when all other methods have failed.
class DurationEstimationContext {
    
    let file: URL
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    var avContext: AVFormatContext {pointer!.pointee}
    
    var duration: Double = 0
    var pktInfo: [PacketInfo] = []
    
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
        var cnt = 0
        
        do {
            
            while true {
                
                let packet = try Packet(pointer)
                if packet.streamIndex == audioStreamIndex {
                    lastPacket = packet
                    cnt += 1
                    
                    let avp = packet.avPacket
//                    print("\nPacket \(cnt):", Double(avp.pts) * theTimeBase.ratio, avp.pos, avp.size, avp.duration)
                    
                    pktInfo.append(PacketInfo(pos: avp.pos, pts: avp.pts))
                }
            }
            
        } catch {
            
            if (error as? CodedError)?.isEOF ?? false, let theLastPacket = lastPacket {
                self.duration = Double(theLastPacket.pts + theLastPacket.duration) * theTimeBase.ratio
                
                let avp = theLastPacket.avPacket
                print("\nLast Packet:", avp.pos, avp.size, self.duration)
            }
        }
    }
    
    func packetPosForTime(_ seconds: Double, _ timeBase: AVRational) -> Int64 {
        
        var minDiff: Int64 = Int64.max
        var tgtIndex = -1
        
        let tgtPts = Int64(seconds / timeBase.ratio)
        
        for (index, info) in pktInfo.enumerated() {
            
            let diff = abs(tgtPts - info.pts)
            
            if diff < minDiff {
                
                minDiff = diff
                tgtIndex = index
            }
        }
        
        return tgtIndex < 0 ? 0 : pktInfo[tgtIndex].pos
    }
}

struct PacketInfo {
    
    let pos: Int64
    let pts: Int64
}
