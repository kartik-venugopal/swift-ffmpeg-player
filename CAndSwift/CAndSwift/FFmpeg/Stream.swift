import Foundation
import ffmpeg

class Stream {
    
    let filePath: String

    var pointer: UnsafeMutablePointer<AVStream>?
    let avStream: AVStream
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>?
    
    init?(_ formatCtx: FormatContext, _ mediaType: AVMediaType) {
        
        self.filePath = formatCtx.filePath
        
        self.index = av_find_best_stream(formatCtx.pointer, mediaType, -1, -1, &codecPointer, 0)
        if index < 0 {
            
            print("\nStream.init(): Unable to find \(mediaType) stream in file '\(filePath)'.")
            return nil
        }

        self.pointer = formatCtx.avContext.streams.advanced(by: Int(index)).pointee
        
        if let pointee = self.pointer?.pointee {
            self.avStream = pointee
            
        } else {
            
            print("\nStream.init(): nil stream in file '\(filePath)'.")
            return nil
        }
    }
}

class AudioStream: Stream {
    
    var duration: Double {Double(avStream.duration) * avStream.time_base.ratio}
    
    init?(_ formatCtx: FormatContext) {
        super.init(formatCtx, AVMEDIA_TYPE_AUDIO)
    }
    
    func printInfo() {
        
        print("\n---------- Stream Info ----------\n")
        
        print(String(format: "Index:   %7d", index))
        print(String(format: "Duration: %7.2lf", duration))
        
        print("---------------------------------\n")
    }
}

class ImageStream: Stream {
    
    init?(_ formatCtx: FormatContext) {
        super.init(formatCtx, AVMEDIA_TYPE_VIDEO)
    }
    
    func printInfo() {
        
        print("\n---------- Stream Info ----------\n")
        
        print(String(format: "Index:   %7d", index))
        
        print("---------------------------------\n")
    }
}
