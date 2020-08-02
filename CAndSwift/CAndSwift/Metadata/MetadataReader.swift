import Cocoa

class MetadataReader {
    
    func readTrack(_ file: URL) -> TrackInfo? {
        
        if let fileCtx = MetadataFileContext(file) {
            
            let audioInfo: AudioInfo = readAudioInfo(file, fileCtx)
            
            let metadata: [String: String] = readAudioMetadata(fileCtx)
            
            let coverArt: NSImage? = readCoverArt(fileCtx)
            let artMetadata: [String: String]? = fileCtx.imageStream?.metadata
            
            let chapters: [Chapter] = fileCtx.format.chapters
            
            return TrackInfo(audioInfo: audioInfo, metadata: metadata, art: coverArt, artMetadata: artMetadata, chapters: chapters)
            
        } else {
            
            print("\nERROR reading metadata from file: \(file.path)")
            return nil
        }
    }
    
    private func readAudioMetadata(_ fileCtx: MetadataFileContext) -> [String: String] {
        
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
    
    private func readAudioInfo(_ file: URL, _ fileCtx: MetadataFileContext) -> AudioInfo {
        
        let stream = fileCtx.audioStream
        let codec = stream.codec

        let fileType: String = file.pathExtension.uppercased()
        let codecName: String = codec.longName
        let duration: Double = stream.duration
        let sampleRate: Int = Int(codec.sampleRate)
        let sampleFormat: SampleFormat = codec.sampleFormat
        let bitRate: Int64 = codec.bitRate > 0 ? codec.bitRate : fileCtx.format.bitRate
        let channelCount: Int = codec.channelCount
//        let frames: Int64 = Int64(round(duration * Double(sampleRate)))
        let frames: Int64 = 0

        return AudioInfo(fileType: fileType, codec: codecName, duration: duration, sampleRate: sampleRate, sampleFormat: sampleFormat, bitRate: bitRate,
                          channelCount: channelCount, frameCount: frames)
    }
    
    private func readCoverArt(_ fileCtx: MetadataFileContext) -> NSImage? {
        
        if let imageStream = fileCtx.imageStream, let imageCodec = fileCtx.imageCodec {
            
            do {
                
                try imageCodec.open()
            
                if let imageDataPacket = try fileCtx.format.readPacket(imageStream), let imageData = imageCodec.decode(imageDataPacket) {
                    return NSImage(data: imageData)
                }
                
            } catch {}
        }
        
        return nil
    }
}
