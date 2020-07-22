import Foundation
import ffmpeg

class FormatContext {

    let file: URL
    let path: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    let avContext: AVFormatContext
    
    init?(_ file: URL) {
        
        self.file = file
        self.path = file.path
        
        self.pointer = avformat_alloc_context()
        
        if avformat_open_input(&pointer, file.path, nil, nil) >= 0, let pointee = pointer?.pointee {
            self.avContext = pointee
        } else {
            return nil
        }
    }
}

class Stream {

    var pointer: UnsafeMutablePointer<AVStream>?
    let avStream: AVStream
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>?
    
    init?(_ formatCtx: FormatContext) {
        
        self.index = av_find_best_stream(formatCtx.pointer, AVMEDIA_TYPE_AUDIO, -1, -1, &codecPointer, 0)
        if index == -1 {
            return nil
        }

        self.pointer = formatCtx.avContext.streams.advanced(by: Int(index)).pointee
        if let pointee = self.pointer?.pointee {
            self.avStream = pointee
        } else {
            return nil
        }
    }
}

class Codec {
    
    var pointer: UnsafeMutablePointer<AVCodec>?
    let avCodec: AVCodec
    
    let contextPointer: UnsafeMutablePointer<AVCodecContext>
    let context: AVCodecContext
    
    let sampleRate: Int32
    let sampleFormat: AVSampleFormat
    let sampleSize: Int
    let timeBase: AVRational
    
    init?(_ stream: Stream) {
    
        contextPointer = avcodec_alloc_context3(pointer)
        avcodec_parameters_to_context(contextPointer, stream.avStream.codecpar)

        guard avcodec_open2(contextPointer, pointer, nil) >= 0, let pointee = pointer?.pointee else {
            return nil
        }
        
        self.avCodec = pointee
        self.context = contextPointer.pointee
        
        self.sampleRate = context.sample_rate
        self.sampleFormat = context.sample_fmt
        self.sampleSize = Int(av_get_bytes_per_sample(sampleFormat))
        self.timeBase = context.time_base
    }
}
