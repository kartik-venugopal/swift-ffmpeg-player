import Foundation
import ffmpeg

class Stream {

    var pointer: UnsafeMutablePointer<AVStream>?
    let avStream: AVStream
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>?
    
    init?(_ formatCtx: FormatContext) {
        
        self.index = av_find_best_stream(formatCtx.pointer, AVMEDIA_TYPE_AUDIO, -1, -1, &codecPointer, 0)
        if index == -1 {return nil}

        self.pointer = formatCtx.avContext.streams.advanced(by: Int(index)).pointee
        
        if let pointee = self.pointer?.pointee {
            self.avStream = pointee
            
        } else {
            return nil
        }
    }
}
