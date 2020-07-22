import Foundation
import ffmpeg

class Stream {
    
    let filePath: String

    var pointer: UnsafeMutablePointer<AVStream>?
    let avStream: AVStream
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>?
    
    var duration: Double {Double(avStream.duration) * avStream.time_base.ratio}
    
    init?(_ formatCtx: FormatContext) {
        
        self.filePath = formatCtx.filePath
        
        let resultCode: Int32 = avformat_find_stream_info(formatCtx.pointer, nil)
        if resultCode < 0 {
            
            print("\nStream.init(): Unable to find stream info for file '\(filePath)'. Error: \(errorString(errorCode: resultCode))")
            return nil
        }
        
        self.index = av_find_best_stream(formatCtx.pointer, AVMEDIA_TYPE_AUDIO, -1, -1, &codecPointer, 0)
        if index == -1 {
            
            print("\nStream.init(): Unable to find audio stream in file '\(filePath)'.")
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
    
    func printInfo() {
        
        print("\n---------- Stream Info ----------\n")
        
        print(String(format: "Index:   %7d", index))
        print(String(format: "Duration: %7.2lf", duration))
        
        print("---------------------------------\n")
    }
}
