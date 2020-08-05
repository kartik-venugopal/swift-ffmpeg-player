import Foundation

///
/// Encapsulates an ffmpeg AVStream struct that represents a single stream,
/// and provides convenient Swift-style access to its functions and member variables.
///
/// Instantiates and provides the codec corresponding to the stream, and a codec context.
///
class Stream {
    
    ///
    /// A pointer to the encapsulated AVStream object.
    ///
    var pointer: UnsafeMutablePointer<AVStream>
    
    ///
    /// The encapsulated AVStream object.
    ///
    var avStream: AVStream {pointer.pointee}
    
    ///
    /// The media type of data contained within this stream (e.g. audio, video, etc)
    ///
    let mediaType: AVMediaType
    
    ///
    /// The index of this stream within its container.
    ///
    let index: Int32
    
    ///
    /// The codec associated with this stream.
    ///
    var codec: Codec {_codec}
    
    ///
    /// The object backing the property **codec**.
    ///
    fileprivate var _codec: Codec!
    
    ///
    /// A pointer to the underlying AVCodec associated with this stream.
    ///
    fileprivate var codecPointer: UnsafeMutablePointer<AVCodec>
    
    ///
    /// The underlying AVCodec associated with this stream.
    ///
    fileprivate var avCodec: AVCodec {codecPointer.pointee}
    
    ///
    /// A pointer to the context for the underlying AVCodec associated with this stream.
    ///
    fileprivate var codecContextPointer: UnsafeMutablePointer<AVCodecContext>
    
    ///
    /// All metadata key / value pairs available for this stream.
    ///
    lazy var metadata: [String: String] = {
        
        var metadata: [String: String] = [:]
        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
        
        while let tag = av_dict_get(avStream.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
            
            metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            tagPtr = tag
        }
        
        return metadata
    }()
    
    ///
    /// Instantiates this stream object and its associated codec and codec context.
    ///
    /// - Parameter pointer: Pointer to the underlying AVStream.
    ///
    /// - Parameter mediaType: The media type of this stream (e.g. audio / video, etc)
    ///
    init(_ pointer: UnsafeMutablePointer<AVStream>, _ mediaType: AVMediaType) {
        
        self.pointer = pointer
        
        self.mediaType = mediaType
        self.index = pointer.pointee.index
        
        // TODO: Maybe move the below code to Codec ??? Or lazily compute it.
        
        // Find the associated codec.
        // TODO: Assert non-nil
        self.codecPointer = avcodec_find_decoder(pointer.pointee.codecpar.pointee.codec_id)
        
        // Allocate a context for the codec.
        self.codecContextPointer = avcodec_alloc_context3(codecPointer)
        // TODO: Assert that the pointee is non-nil.
        
        // Copy the codec's parameters to the codec context.
        avcodec_parameters_to_context(codecContextPointer, pointer.pointee.codecpar)
        
        // Only instantiate the codec if this stream is neither audio or video.
        // NOTE - AudioStream and ImageStream will instantiate their own codecs.
        
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

///
/// A Stream whose media type is audio.
///
class AudioStream: Stream {
    
    override var codec: AudioCodec {_codec as! AudioCodec}
    
    var duration: Double?
    var timeBase: AVRational {avStream.time_base}
    var frameCount: Int64 {avStream.duration}
    
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        
        super.init(pointer, AVMEDIA_TYPE_AUDIO)
        
        self._codec = AudioCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
        self.duration = avStream.duration > 0 ? Double(avStream.duration) * avStream.time_base.ratio : nil
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

///
/// A Stream whose media type is video (i.e. cover art).
///
class ImageStream: Stream {
    
    override var codec: ImageCodec {_codec as! ImageCodec}
    
    var attachedPic: AVPacket {avStream.attached_pic}
    
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        
        super.init(pointer, AVMEDIA_TYPE_VIDEO)
        self._codec = ImageCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
    }
}

///
/// Convenience functions that are useful when converting between stream time units and seconds (used by the user interface).
///
extension AVRational {

    var ratio: Double {Double(num) / Double(den)}
    var reciprocal: Double {Double(den) / Double(num)}
}
