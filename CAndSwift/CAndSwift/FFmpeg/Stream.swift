import Foundation

class Stream {
    
    var pointer: UnsafeMutablePointer<AVStream>
    var avStream: AVStream {pointer.pointee}
    
    let mediaType: AVMediaType
    let index: Int32
    
    var codecPointer: UnsafeMutablePointer<AVCodec>
    var avCodec: AVCodec {codecPointer.pointee}
    var codecContextPointer: UnsafeMutablePointer<AVCodecContext>
    
    fileprivate var _codec: Codec!
    var codec: Codec {_codec}
    
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
        
        if mediaType != AVMEDIA_TYPE_AUDIO && mediaType != AVMEDIA_TYPE_VIDEO {
            _codec = Codec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
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
    
    override var codec: AudioCodec {_codec as! AudioCodec}
    
    var duration: Double?
    var timeBase: AVRational {avStream.time_base}
    var frameCount: Int64 {avStream.duration}
    
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        
        super.init(pointer, AVMEDIA_TYPE_AUDIO)
        
        self._codec = AudioCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
        self.duration = avStream.duration > 0 ? Double(avStream.duration) * avStream.time_base.ratio : nil
        
//        print("Stream: Duration= \(avStream.duration), TimeBase= \(avStream.time_base.num) / \(avStream.time_base.den)")
    }
    
    override func printInfo() {
        
        print("\n---------- Audio Stream Info ----------\n")
        
        print(String(format: "Index:         %7d", index))
        print(String(format: "Duration:      %@", duration != nil ? String(format: "%7.2lf", duration!) : "<Unknown>" ))
        print(String(format: "Time Base:     %d / %d", timeBase.num, timeBase.den))
        print(String(format: "Total Frames:  %7ld", frameCount))
        
        print("---------------------------------\n")
    }
}

class ImageStream: Stream {
    
    override var codec: ImageCodec {_codec as! ImageCodec}
    
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        
        super.init(pointer, AVMEDIA_TYPE_VIDEO)
        self._codec = ImageCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
    }
}

extension AVRational {

    var ratio: Double {Double(num) / Double(den)}
    var reciprocal: Double {Double(den) / Double(num)}
}
