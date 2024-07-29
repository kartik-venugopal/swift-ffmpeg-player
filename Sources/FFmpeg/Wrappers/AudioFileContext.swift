import Foundation
import AVFoundation

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
    let format: FFmpegFormatContext

    ///
    /// The first / best audio stream in the file.
    ///
    /// # Note #
    ///
    /// This property provides the convenience of accessing the audio stream within **format**.
    /// The same AudioStream may be obtained by calling **format.audioStream**.
    ///
    let audioStream: FFmpegAudioStream
    
    ///
    /// The codec used to decode packets read from the audio stream.
    ///
    let audioCodec: FFmpegAudioCodec
    
    ///
    /// The (optional) video stream that contains cover art, if present. Nil otherwise.
    ///
    let imageStream: FFmpegImageStream?
    
    let decoder: FFmpegDecoder
    
    let audioFormat: AVAudioFormat
    
    ///
    /// The maximum number of samples that will be read, decoded, and scheduled for **immediate** playback,
    /// i.e. when **play(file)** is called, triggered by the user.
    ///
    /// # Notes #
    ///
    /// 1. This value should be small enough so that, when starting playback
    /// of a file, there is little to no perceived lag. Typically, this should represent about 2-5 seconds of audio (depending on sample rate).
    ///
    /// 2. This value should generally be smaller than *sampleCountForDeferredPlayback*.
    ///
    let sampleCountForImmediatePlayback: Int32
    
    ///
    /// The maximum number of samples that will be read, decoded, and scheduled for **deferred** playback, i.e. playback that will occur
    /// at a later time, as the result, of a recursive scheduling task automatically triggered when a previously scheduled audio buffer has finished playing.
    ///
    /// # Notes #
    ///
    /// 1. The greater this value, the longer each recursive scheduling task will take to complete, and the larger the memory footprint of each audio buffer.
    /// The smaller this value, the more often disk reads will occur. Choose a value that is a good balance between memory usage, decoding / resampling time, and frequency of disk reads.
    /// Example: 10-20 seconds of audio (depending on sample rate).
    ///
    /// 2. This value should generally be larger than *sampleCountForImmediatePlayback*.
    ///
    let sampleCountForDeferredPlayback: Int32
    
    let sampleRate: Double
    
    let frameCount: Int64
    
    var duration: Double {format.duration}
    
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
    init?(forFile file: URL) {
        
        self.file = file
    
        // 1 - Attempt to instantiate a FormatContext to mux the file into streams.
        // 2 - Then, attempt to obtain audio and image streams from the FormatContext.
        // 3 - Finally, get the codec associated with the audio stream (for decoding).
        
        // If any of the above steps fail, we cannot proceed with reading / decoding this file, so return nil.
        
        guard let theFormatContext = try? FFmpegFormatContext(for: file),
                let theAudioStream = theFormatContext.bestAudioStream,
                let theDecoder = try? FFmpegDecoder(for: theFormatContext) else {return nil}

        self.format = theFormatContext
        self.audioStream = theAudioStream
        self.audioCodec = theDecoder.codec
        
        self.imageStream = theFormatContext.bestImageStream
        
        self.decoder = theDecoder
        
        let codec = theDecoder.codec
        
        let sampleRate: Int32 = codec.sampleRate
        let sampleRateDouble: Double = Double(sampleRate)

        self.sampleRate = sampleRateDouble
        self.frameCount = Int64(sampleRateDouble * theFormatContext.duration)
        
        let channelLayout: AVAudioChannelLayout = codec.channelLayout.avfLayout ?? .stereo
        
        self.audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRateDouble, channelLayout: channelLayout)

        // The effective sample rate, which also takes into account the channel count, gives us a better idea
        // of the computational cost of decoding and resampling the given file, as opposed to just the
        // sample rate.
        let channelCount: Int32 = codec.channelCount
        let effectiveSampleRate: Int32 = sampleRate * channelCount

        switch effectiveSampleRate {

        case 0..<100000:

            // 44.1 / 48 KHz stereo

            sampleCountForImmediatePlayback = 5 * sampleRate    // 5 seconds of audio
            sampleCountForDeferredPlayback = 10 * sampleRate    // 10 seconds of audio

        case 100000..<500000:

            // 96 / 192 KHz stereo

            sampleCountForImmediatePlayback = 3 * sampleRate    // 3 seconds of audio
            sampleCountForDeferredPlayback = 7 * sampleRate    // 7 seconds of audio

        default:

            // 96 KHz surround and higher sample rates

            sampleCountForImmediatePlayback = 2 * sampleRate    // 2 seconds of audio
            sampleCountForDeferredPlayback = 5 * sampleRate     // 5 seconds of audio
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

extension AVAudioChannelLayout {
    
    static let stereo: AVAudioChannelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
}
