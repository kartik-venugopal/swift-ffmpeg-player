import Foundation

///
/// Encapsulates an ffmpeg AVStream struct that represents a single stream,
/// and provides convenient Swift-style access to its functions and member variables.
///
/// Instantiates and provides the codec corresponding to the stream, and a codec context.
///
class ImageStream: Stream {
    
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
    let mediaType: AVMediaType = AVMEDIA_TYPE_VIDEO
    
    ///
    /// The index of this stream within its container.
    ///
    let index: Int32
    
    ///
    /// The codec associated with this stream.
    ///
    var codec: ImageCodec
    
    ///
    /// A pointer to the underlying AVCodec associated with this stream.
    ///
    var codecPointer: UnsafeMutablePointer<AVCodec>
    
    ///
    /// The underlying AVCodec associated with this stream.
    ///
    var avCodec: AVCodec {codecPointer.pointee}
    
    ///
    /// A pointer to the context for the underlying AVCodec associated with this stream.
    ///
    var codecContextPointer: UnsafeMutablePointer<AVCodecContext>
    
    ///
    /// The packet (optionally) containing an attached picture.
    /// This can be used to read cover art.
    ///
    var attachedPic: Packet {Packet(avPacket: avStream.attached_pic)}
    
    ///
    /// All metadata key / value pairs available for this stream.
    ///
    lazy var metadata: [String: String] = {
        MetadataDictionary(pointer: avStream.metadata).dictionary
    }()
    
    ///
    /// Instantiates this stream object and its associated codec and codec context.
    ///
    /// - Parameter pointer: Pointer to the underlying AVStream.
    ///
    /// - Parameter mediaType: The media type of this stream (e.g. audio / video, etc)
    ///
    init(_ pointer: UnsafeMutablePointer<AVStream>) {
        
        self.pointer = pointer
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
        self.codec = ImageCodec(pointer: codecPointer, contextPointer: codecContextPointer, paramsPointer: pointer.pointee.codecpar)
    }
    
    func printInfo() {
        
        print("\n---------- Stream Info ----------\n")
        
        print(String(format: "Index:        %7d", index))
        print(String(format: "Media Type:   %7d", mediaType.rawValue))
        
        print("---------------------------------\n")
    }
}
