import Foundation

struct FFmpegAudioFormat {
    
    let sampleRate: Int32
    let channelCount: Int32
    let channelLayout: Int64
    let sampleFormat: SampleFormat
    
    var needsFormatConversion: Bool {sampleFormat.needsFormatConversion}
}
