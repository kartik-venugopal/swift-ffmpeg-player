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
    /// - Parameter fileCtx: A valid AudioFileContext for the file being read.
    ///
    /// - returns: All available track metadata for the file pointed to by **fileCtx**.
    ///
    func readTrack(_ fileCtx: AudioFileContext) -> TrackInfo {
        
        let audioInfo: AudioInfo = readAudioInfo(fileCtx)
        let metadata: [String: String] = readAudioMetadata(fileCtx)
        
        let coverArt: NSImage? = readCoverArt(fileCtx)
        let artMetadata: [String: String]? = fileCtx.imageStream?.metadata
        
        let chapters: [Chapter] = fileCtx.format.chapters
        
        return TrackInfo(audioInfo: audioInfo, metadata: metadata, art: coverArt, artMetadata: artMetadata, chapters: chapters)
    }
    
    ///
    /// Given a file context, reads and returns all available stream and container metadata, e.g. ID3 / iTunes tags.
    ///
    /// - Parameter fileCtx: A valid AudioFileContext for the file being read.
    ///
    /// - returns: All available stream / container metadata for the file pointed to by **fileCtx**.
    ///
    private func readAudioMetadata(_ fileCtx: AudioFileContext) -> [String: String] {
        
        // Combine metadata from the format context and audio stream.
        
        var metadata: [String: String] = [:]
        
        for (key, value) in fileCtx.format.metadata {
            metadata[key] = value
        }
        
        for (key, value) in fileCtx.audioStream.metadata {
            metadata[key] = value
        }
        
        return metadata
    }
    
    ///
    /// Given a file context, reads and returns technical audio data for its audio stream. e.g. codec name, sample rate, bit rate, etc.
    ///
    /// - Parameter fileCtx: A valid AudioFileContext for the file being read.
    ///
    /// - returns: All available technical audio stream data.
    ///
    private func readAudioInfo(_ fileCtx: AudioFileContext) -> AudioInfo {
        
        let stream = fileCtx.audioStream
        let codec = stream.codec

        let fileType: String = fileCtx.file.pathExtension.uppercased()
        let codecName: String = codec.longName
        let duration: Double = fileCtx.format.duration
        let sampleRate: Int = Int(codec.sampleRate)
        let sampleFormat: SampleFormat = codec.sampleFormat
        let bitRate: Int64 = codec.bitRate > 0 ? codec.bitRate : fileCtx.format.bitRate
        
        // TODO: Instead of a simple channel count, display a more meaningful description (e.g. "5.1 - LR LF LC BL BR)"
        let channelCount: Int = Int(codec.channelCount)
        
        let frames: Int64 = Int64(floor(duration * Double(sampleRate)))

        return AudioInfo(fileType: fileType, codec: codecName, duration: duration, sampleRate: sampleRate, sampleFormat: sampleFormat, bitRate: bitRate,
                          channelCount: channelCount, frameCount: frames)
    }
    
    ///
    /// Given a file context, reads and returns cover art for the file, if present.
    ///
    /// - Parameter fileCtx: A valid AudioFileContext for the file being read.
    ///
    /// - returns: An NSImage containing the cover art for the file, if present. Nil otherwise.
    ///
    private func readCoverArt(_ fileCtx: AudioFileContext) -> NSImage? {
        
        // If no image (video) stream is present within the file, there is no cover art.
        guard let imageStream = fileCtx.imageStream else {return nil}
            
        do {

            // Found an image stream, now try to read a single packet from it.
            
            if let imageDataPacket = try fileCtx.format.readPacket(imageStream),
                let imageData = imageDataPacket.data {
            
                // Wrap the raw packet data in an NSImage and return it.
                return NSImage(data: imageData)
            }
            
        } catch {
            print("Error reading cover art:", error)
        }
        
        return nil
    }
}
