import Foundation

///
/// Encapsulates all information about the audio format of a track.
///
/// Analogous to **AVAudioFormat** in AVFoundation.
///
struct FFmpegAudioFormat {
    
    /// Samples per second
    let sampleRate: Int32
    
    /// Number of channels of audio
    let channelCount: Int32
    
    /// An ffmpeg identifier for the physical / spatial layout of channels. eg. "5.1 surround" or "stereo".
    let channelLayout: Int64
    
    /// PCM sample format
    let sampleFormat: SampleFormat
    
    ///
    /// Whether or not samples of this format require conversion before they can be fed into AVAudioEngine for playback.
    ///
    /// Will be true unless the sample format is 32-bit float non-interleaved (i.e. the standard Core Audio format).
    ///
    var needsFormatConversion: Bool {sampleFormat.needsFormatConversion}
}
