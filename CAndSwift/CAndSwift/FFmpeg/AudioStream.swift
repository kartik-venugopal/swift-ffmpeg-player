import Foundation

///
/// Encapsulates an ffmpeg AVStream struct that represents a single audio stream,
/// and provides convenient Swift-style access to its functions and member variables.
///
/// Instantiates and provides the codec corresponding to the stream, and a codec context.
///
class AudioStream: StreamProtocol {
    
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
    let mediaType: AVMediaType = AVMEDIA_TYPE_AUDIO
    
    ///
    /// The index of this stream within its container.
    ///
    let index: Int32
    
    ///
    /// The codec associated with this stream.
    ///
    lazy var codec: AudioCodec? = {
        return AudioCodec(paramsPointer: avStream.codecpar)
    }()
    
    ///
    /// The duration of this stream, in seconds, if available. Nil if not available.
    ///
    /// # Notes #
    ///
    /// This may not be available or may not be accurate for some streams
    /// like those in raw audio files without containers (e.g. aac, dts, ac3, etc.)
    ///
    var duration: Double?
    
    ///
    /// Unit of time in which frame timestamps are represented in this stream.
    ///
    var timeBase: AVRational {avStream.time_base}
    
    ///
    /// The duration of this stream, in time base units.
    ///
    /// # Notes #
    ///
    /// This may not be available or may not be accurate for some streams
    /// like those in raw audio files without containers (e.g. aac, dts, ac3, etc.)
    ///
    var timeBaseDuration: Int64 {avStream.duration}
    
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
        self.duration = avStream.duration > 0 ? Double(avStream.duration) * avStream.time_base.ratio : nil
    }
    
    ///
    /// Print some stream info to the console.
    /// May be used to verify that the stream was properly read / initialized.
    /// Useful for debugging purposes.
    ///
    func printInfo() {
        
        print("\n---------- Audio Stream Info ----------\n")
        
        print(String(format: "Index:         %7d", index))
        print(String(format: "Duration:      %@", duration != nil ? String(format: "%7.2lf", duration!) : "<Unknown>" ))
        print(String(format: "Time Base:     %d / %d", timeBase.num, timeBase.den))
        print(String(format: "Total Frames:  %7ld", timeBaseDuration))
        
        print("---------------------------------\n")
    }
}
