import Foundation

class Stream {
    
    var pointer: UnsafeMutablePointer<AVStream>
    var avStream: AVStream {pointer.pointee}
    
    let mediaType: AVMediaType
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>
    var avCodec: AVCodec {codecPointer.pointee}
    var codecContextPointer: UnsafeMutablePointer<AVCodecContext>
    
    var codec: Codec
    
    var metadata: [String: String] {
        
        var metadata: [String: String] = [:]
        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
        
        while let tag = av_dict_get(avStream.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
            
            metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            tagPtr = tag
        }
        
        return metadata
    }
    
    init(_ pointer: UnsafeMutablePointer<AVStream>, _ mediaType: AVMediaType) {
        
        self.pointer = pointer
        
        self.mediaType = mediaType
        self.index = pointer.pointee.index
        
        self.codecPointer = avcodec_find_decoder(pointer.pointee.codecpar.pointee.codec_id)
        
        self.codecContextPointer = avcodec_alloc_context3(codecPointer)
        avcodec_parameters_to_context(codecContextPointer, pointer.pointee.codecpar)
        
        switch mediaType {
            
        case AVMEDIA_TYPE_AUDIO:
            
            self.codec = AudioCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
            
        case AVMEDIA_TYPE_VIDEO:
            
            self.codec = ImageCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
            
        default:
            
            self.codec = Codec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
        }
    }
    
    func printInfo() {
        
        print("\n---------- Stream Info ----------\n")
        
        print(String(format: "Index:        %7d", index))
        print(String(format: "Media Type:   %7d", mediaType.rawValue))
        
        print("---------------------------------\n")
    }
}

class AudioStream: Stream {
    
    var duration: Double = 0
    var timeBase: AVRational {avStream.time_base}
    var frameCount: Int64 {avStream.duration}
    
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        
        super.init(pointer, AVMEDIA_TYPE_AUDIO)
        self.duration = Double(avStream.duration) * avStream.time_base.ratio
    }
    
    override func printInfo() {
        
        print("\n---------- Audio Stream Info ----------\n")
        
        print(String(format: "Index:         %7d", index))
        print(String(format: "Duration:      %7.2lf", duration))
        print(String(format: "Time Base:     %d / %d", timeBase.num, timeBase.den))
        print(String(format: "Total Frames:  %7ld", frameCount))
        
        print("---------------------------------\n")
    }
}

class ImageStream: Stream {
    
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        super.init(pointer, AVMEDIA_TYPE_VIDEO)
    }
}
