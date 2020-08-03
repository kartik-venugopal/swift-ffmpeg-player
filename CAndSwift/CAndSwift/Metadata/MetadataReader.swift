import Cocoa

class MetadataReader {
    
    func readTrack(_ fileCtx: AudioFileContext) -> TrackInfo {
        
        let audioInfo: AudioInfo = readAudioInfo(fileCtx)
        
        let metadata: [String: String] = readAudioMetadata(fileCtx)
        
        let coverArt: NSImage? = readCoverArt(fileCtx)
        let artMetadata: [String: String]? = fileCtx.imageStream?.metadata
        
        let chapters: [Chapter] = fileCtx.format.chapters
        
        return TrackInfo(audioInfo: audioInfo, metadata: metadata, art: coverArt, artMetadata: artMetadata, chapters: chapters)
    }
    
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
    
    private func readAudioInfo(_ fileCtx: AudioFileContext) -> AudioInfo {
        
        let stream = fileCtx.audioStream
        let codec = stream.codec

        let fileType: String = fileCtx.file.pathExtension.uppercased()
        let codecName: String = codec.longName
        let duration: Double = fileCtx.format.duration
        let sampleRate: Int = Int(codec.sampleRate)
        let sampleFormat: SampleFormat = codec.sampleFormat
        let bitRate: Int64 = codec.bitRate > 0 ? codec.bitRate : fileCtx.format.bitRate
        let channelCount: Int = codec.channelCount
        let frames: Int64 = Int64(floor(duration * Double(sampleRate)))

        return AudioInfo(fileType: fileType, codec: codecName, duration: duration, sampleRate: sampleRate, sampleFormat: sampleFormat, bitRate: bitRate,
                          channelCount: channelCount, frameCount: frames)
    }
    
    private func readCoverArt(_ fileCtx: AudioFileContext) -> NSImage? {
        
        if let imageStream = fileCtx.imageStream, let imageCodec = fileCtx.imageCodec {
            
            do {
                
                try imageCodec.open()
            
                if let imageDataPacket = try fileCtx.format.readPacket(imageStream), let imageData = imageCodec.decode(imageDataPacket) {
                    return NSImage(data: imageData)
                }
                
            } catch {
                print("CoverArt error:", error)
            }
        }
        
        return nil
    }
}
