import Foundation

///
/// Encapsulates a context for reading audio data / metadata from a single audio file using ffmpeg.
///
/// Instantiates, provides, and manages the life cycles of several member objects through which several ffmpeg functions can be executed.
///
class AudioFileContext {

    ///
    /// The audio file to be read / decoded by this context.
    ///
    let file: URL
    
    ///
    /// A context representing the file's container format.
    /// Used to obtain streams and read (coded) packets.
    ///
    let format: FormatContext

    ///
    /// The first / best audio stream in the file.
    ///
    /// # Note #
    ///
    /// This property provides the convenience of accessing the audio stream within **format**.
    /// The same AudioStream may be obtained by calling **format.audioStream**.
    ///
    let audioStream: AudioStream
    
    ///
    /// The codec used to decode packets read from the audio stream.
    ///
    let audioCodec: AudioCodec
    
    ///
    /// The (optional) video stream that contains cover art, if present. Nil otherwise.
    ///
    let imageStream: ImageStream?
    
    ///
    /// Attempts to construct an AudioFileContext instance for the given file.
    ///
    /// - Parameter file: The audio file to be read / decoded by this context.
    ///
    /// Fails (returns nil) if:
    ///
    /// - An error occurs while opening the file or reading (demuxing) its streams.
    /// - No audio stream is found in the file.
    /// - No suitable codec is found for the audio stream.
    ///
    /// # Note #
    ///
    /// If this initializer succeeds (does not return nil), it indicates that the file being read:
    ///
    /// 1. Is a valid media file.
    /// 2. Has at least one audio stream.
    /// 3. Is able to decode that audio stream.
    ///
    init?(_ file: URL) {
        
        self.file = file
    
        // 1 - Attempt to instantiate a FormatContext to mux the file into streams.
        // 2 - Then, attempt to obtain audio and image streams from the FormatContext.
        // 3 - Finally, get the codec associated with the audio stream (for decoding).
        
        // If any of the above steps fail, we cannot proceed with reading / decoding this file, so return nil.
        
        guard let theFormatContext = FormatContext(file), let theAudioStream = theFormatContext.audioStream, let theAudioCodec = theAudioStream.codec else {return nil}

        self.format = theFormatContext
        self.audioStream = theAudioStream
        self.audioCodec = theAudioCodec
        
        self.imageStream = theFormatContext.imageStream
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

        // Destroy the constituent objects themselves.
        
        audioCodec.destroy()
        format.destroy()
        
        destroyed = true
    }
    
    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}
