import Foundation

///
/// Encapsulates an ffmpeg AVCodec, AVCodecContext, and AVCodecParameters struct,
/// and provides convenient Swift-style access to their functions and member variables.
///
class Codec {
    
    ///
    /// A pointer to the encapsulated AVCodec object.
    ///
    var pointer: UnsafeMutablePointer<AVCodec>
    
    ///
    /// The encapsulated AVCodec object.
    ///
    var avCodec: AVCodec {pointer.pointee}
    
    ///
    /// A pointer to a context for the encapsulated AVCodec object.
    ///
    var contextPointer: UnsafeMutablePointer<AVCodecContext>?
    
    ///
    /// A context for the encapsulated AVCodec object.
    ///
    var context: AVCodecContext {contextPointer!.pointee}
    
    ///
    /// A pointer to parameters for the encapsulated AVCodec object.
    ///
    var paramsPointer: UnsafeMutablePointer<AVCodecParameters>
    
    ///
    /// Parameters for the encapsulated AVCodec object.
    ///
    var params: AVCodecParameters {paramsPointer.pointee}
    
    ///
    /// The unique identifier of the encapsulated AVCodec object.
    ///
    var id: UInt32 {avCodec.id.rawValue}
    
    ///
    /// The name of the encapsulated AVCodec object.
    ///
    var name: String {String(cString: avCodec.name)}
    
    ///
    /// The long name of the encapsulated AVCodec object.
    ///
    var longName: String {String(cString: avCodec.long_name)}
    
    ///
    /// Instantiates a Codec object, given a pointer to its parameters.
    ///
    /// - Parameter paramsPointer: A pointer to parameters for the associated AVCodec object.
    ///
    init(paramsPointer: UnsafeMutablePointer<AVCodecParameters>) {
        
        // TODO: Nil checks (don't force unwrap).
        
        self.paramsPointer = paramsPointer
        
        // Find the codec by ID.
        self.pointer = avcodec_find_decoder(paramsPointer.pointee.codec_id)!
        
        // Allocate a context for the codec.
        self.contextPointer = avcodec_alloc_context3(pointer)
        
        // Copy the codec's parameters to the codec context.
        avcodec_parameters_to_context(contextPointer, paramsPointer)
    }
    
    ///
    /// Opens the codec for decoding.
    ///
    /// - throws: **DecoderInitializationError** if the codec cannot be opened.
    ///
    func open() throws {
        
        let codecOpenResult: ResultCode = avcodec_open2(contextPointer, pointer, nil)
        if codecOpenResult.isNonZero {
            
            print("\nCodec.open(): Failed to open codec '\(name)'. Error: \(codecOpenResult.errorDescription))")
            throw DecoderInitializationError(codecOpenResult)
        }
    }
    
    /// Indicates whether or not this object has already been destroyed.
    private var destroyed: Bool = false
    
    ///
    /// Performs cleanup (deallocation of allocated memory space) when
    /// this object is about to be deinitialized or is no longer needed.
    ///
    func destroy() {

        // This check ensures that the deallocation happens
        // only once. Otherwise, a fatal error will be
        // thrown.
        if destroyed {return}
        
        if avcodec_is_open(contextPointer).isPositive {
            avcodec_close(contextPointer)
        }
        
        avcodec_free_context(&contextPointer)

        destroyed = true
    }

    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}

///
/// A Codec that reads image data (i.e. cover art).
///
class ImageCodec: Codec {}
