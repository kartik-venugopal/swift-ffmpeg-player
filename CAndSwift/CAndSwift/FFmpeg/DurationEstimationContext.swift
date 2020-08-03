import Foundation

// A utility that calculates the duration of an audio track by brute force,
// i.e. reading all packets. This method of duration computation should
// be used as the last resort when all other methods have failed.
class DurationEstimationContext {
    
    let file: URL
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    var avContext: AVFormatContext {pointer!.pointee}
    
    var duration: Double = 0
    var timeBase: AVRational = AVRational()
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
        
        self.timeBase = theTimeBase
        
        var lastPacket: Packet!
        
        do {
            
            while true {
                
                let packet = try Packet(pointer)
                
                if packet.streamIndex == audioStreamIndex {
                    
                    lastPacket = packet
                    pktInfo.append(PacketInfo(pos: packet.pos, pts: packet.pts))
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
    
    func packetPosForTime(_ seconds: Double) -> Int64 {
        
        let tgtPts = Int64(seconds / timeBase.ratio)
        let tgtIndex = searchByPTS(tgtPts)
        
        return tgtIndex < 0 ? 0 : pktInfo[tgtIndex].pos
    }
    
    func searchByPTS(_ tgtPts: Int64) -> Int {
        
        // Binary search algorithm (assumes packets are chronologically arranged).
        
        var first = 0
        var last = pktInfo.count - 1
        var center = (first + last) / 2
        
        var centerPkt = pktInfo[center]
        
        while first <= last {
            
            if tgtPts == centerPkt.pts  {
                
                // Found a matching packet
                return center - 1
                
            } else if tgtPts < centerPkt.pts {
                
                last = center - 1
                
            } else if tgtPts > centerPkt.pts {
                
                first = center + 1
            }
            
            center = (first + last) / 2
            centerPkt = pktInfo[center]
        }
        
        // If no matching packet was found for the target PTS, try to determine a previous packet.
        return tgtPts < centerPkt.pts ? center - 1 : center
    }
}

struct PacketInfo {
    
    let pos: Int64
    let pts: Int64
}
