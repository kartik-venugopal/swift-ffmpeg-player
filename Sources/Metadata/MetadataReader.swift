import Cocoa

///
/// Reads all metadata (audio / image) for an audio track and provides it in a format
/// suitable for consumption by a user interface.
///
/// - Artist / album / genre / year, etc
/// - Cover art.
/// - Chapter markings.
/// - Technical audio data (codec, sample rate, bit rate, bit depth, etc).
///
class MetadataReader {
   
    ///
    /// Given a file context, reads and returns all available track metadata.
    ///
    /// - Parameter fileCtx: A valid FFmpegFileContext for the file being read.
    ///
    /// - returns: All available track metadata for the file pointed to by **fileCtx**.
    ///
    func readMetadata(forFile fileContext: AudioFileContext) -> TrackInfo {
        
        let audioInfo: AudioInfo = readAudioInfo(fileContext)
        let metadata: [String: String] = readAudioMetadata(fileContext.format)
        
        let coverArt: NSImage? = readCoverArt(fileContext)
        let artMetadata: [String: String]? = fileContext.imageStream?.metadata
        
        return TrackInfo(audioInfo: audioInfo, metadata: metadata, art: coverArt, artMetadata: artMetadata)
    }
    
    ///
    /// Given a file context, reads and returns all available stream and container metadata, e.g. ID3 / iTunes tags.
    ///
    /// - Parameter fileCtx: A valid FFmpegFileContext for the file being read.
    ///
    /// - returns: All available stream / container metadata for the file pointed to by **fileCtx**.
    ///
    private func readAudioMetadata(_ formatCtx: FFmpegFormatContext) -> [String: String] {
        
        // Combine metadata from the format context and audio stream.
        
        var metadata: [String: String] = [:]
        
        for (key, value) in formatCtx.metadata {
            metadata[key] = value
        }
        
        for (key, value) in formatCtx.bestAudioStream?.metadata ?? [:] {
            metadata[key] = value
        }
        
        return metadata
    }
    
    ///
    /// Given a file context, reads and returns technical audio data for its audio stream. e.g. codec name, sample rate, bit rate, etc.
    ///
    /// - Parameter fileCtx: A valid FFmpegFileContext for the file being read.
    ///
    /// - returns: All available technical audio stream data.
    ///
    private func readAudioInfo(_ fileCtx: AudioFileContext) -> AudioInfo {
        
        let codec = fileCtx.audioCodec

        let fileType: String = fileCtx.file.pathExtension.uppercased()
        let codecName: String = codec.longName
        let duration: Double = fileCtx.format.duration
        let sampleRate: Int = Int(codec.sampleRate)
        let sampleFormat: FFmpegSampleFormat = codec.sampleFormat
        let bitRate: Int64 = codec.bitRate > 0 ? codec.bitRate : fileCtx.format.bitRate
        let channelLayoutString: String = FFmpegChannelLayoutsMapper.readableString(for: codec.channelLayout, channelCount: codec.channelCount)
        
        let frames: Int64 = Int64(floor(duration * Double(sampleRate)))

        return AudioInfo(fileType: fileType, codec: codecName, duration: duration, sampleRate: sampleRate, sampleFormat: sampleFormat, bitRate: bitRate,
                          channelLayout: channelLayoutString, frameCount: frames)
    }
    
    ///
    /// Given a file context, reads and returns cover art for the file, if present.
    ///
    /// - Parameter fileCtx: A valid FFmpegFileContext for the file being read.
    ///
    /// - returns: An NSImage containing the cover art for the file, if present. Nil otherwise.
    ///
    private func readCoverArt(_ fileCtx: AudioFileContext) -> NSImage? {
        
        // If no image (video) stream is present within the file, there is no cover art.
        // Check if the attached pic in the image stream
        // has any data.
        if let imageData = fileCtx.imageStream?.attachedPic.data {
            return NSImage(data: imageData)
        }
        
        // No attached pic data.
        return nil
    }
}
