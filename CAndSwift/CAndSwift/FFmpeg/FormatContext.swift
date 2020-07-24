import Foundation

class FormatContext {

    let file: URL
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    var avContext: AVFormatContext {pointer!.pointee}
    
    var streams: [Stream]
    var streamCount: Int {streams.count}
    
    var audioStream: AudioStream? {
        streams.compactMap {$0 as? AudioStream}.first
    }
    
    var imageStream: ImageStream? {
        streams.compactMap {$0 as? ImageStream}.first
    }
    
    var metadata: [String: String] {
        readMetadata(ptr: avContext.metadata)
    }
    
    var chapters: [Chapter] {
        
        var chapters: [Chapter] = []
        let numChapters = Int(avContext.nb_chapters)
        
        if let avChapters = avContext.chapters {
            
            // Sort by start time in ascending order
            let theChapters: [AVChapter] = (0..<numChapters).compactMap {avChapters.advanced(by: $0).pointee?.pointee}
                .sorted(by: {c1, c2 in c1.start < c2.start})
            
            for (index, chapter) in theChapters.enumerated() {
                
                let conversionFactor: Double = Double(chapter.time_base.num) / Double(chapter.time_base.den)
                let startTime = Double(chapter.start) * conversionFactor
                let endTime = Double(chapter.end) * conversionFactor
                let title = readMetadata(ptr: chapter.metadata)["title"] ?? "Chapter \(index + 1)"
                
                chapters.append(Chapter(startTime: startTime, endTime: endTime, title: title))
            }
        }
        
        return chapters
    }
    
    init?(_ file: URL) {
        
        self.file = file
        self.filePath = file.path
        
        self.pointer = avformat_alloc_context()
        
        var resultCode: ResultCode = avformat_open_input(&pointer, file.path, nil, nil)
        guard resultCode.isNonNegative, pointer?.pointee != nil else {
            
            print("\nFormatContext.init(): Unable to open file '\(filePath)'. Error: \(resultCode.errorDescription)")
            return nil
        }
        
        resultCode = avformat_find_stream_info(pointer, nil)
        guard resultCode.isNonNegative else {
            
            print("\nFormatContext.init(): Unable to find stream info for file '\(filePath)'. Error: \(resultCode.errorDescription)")
            return nil
        }
        
        self.streams = []
        
        if let streams = avContext.streams {
        
            let avStreamPointers: [UnsafeMutablePointer<AVStream>] = (0..<avContext.nb_streams).compactMap {streams.advanced(by: Int($0)).pointee}
            
            self.streams = avStreamPointers.compactMap {pointer in
                
                switch pointer.pointee.codecpar.pointee.codec_type {
                    
                case AVMEDIA_TYPE_AUDIO:    return AudioStream(pointer)
                    
                case AVMEDIA_TYPE_VIDEO:    return ImageStream(pointer)
                    
                default:                    return nil
                    
                }
            }
        }
    }
    
    func readPacket(_ stream: Stream) throws -> Packet? {
        
        let packet = Packet()

        let readResult: ResultCode = av_read_frame(pointer, packet.pointer)
        guard readResult.isNonNegative else {
            
            print("\nFormatContext.readPacket(): Unable to read packet. Error: \(readResult) (\(readResult.errorDescription)))")
            throw PacketReadError(readResult)
        }
        
        return packet.streamIndex == stream.index ? packet : nil
    }
    
    func seekWithinStream(_ stream: AudioStream, _ time: Double) throws {
        
        let seekPosRatio = time / stream.duration
        let targetFrame = Int64(seekPosRatio * Double(stream.avStream.duration))

        // Track playback completed. Send EOF code.
        if targetFrame >= stream.frameCount {
            throw SeekError(EOF_CODE)
        }

        let seekResult: ResultCode = av_seek_frame(pointer, stream.index, targetFrame, AVSEEK_FLAG_ANY)
        guard seekResult.isNonNegative else {

            print("\nFormatContext.seekWithinStream(): Unable to seek within stream \(stream.index). Error: \(seekResult) (\(seekResult.errorDescription)))")
            throw SeekError(seekResult)
        }
    }
    
    private func readMetadata(ptr: OpaquePointer!) -> [String: String] {
        
        var metadata: [String: String] = [:]
        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
        
        while let tag = av_dict_get(ptr, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
            
            metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            tagPtr = tag
        }
        
        return metadata
    }
    
    private var destroyed: Bool = false
    
    func destroy() {
        
        if destroyed {return}
        
        avformat_close_input(&pointer)
        avformat_free_context(pointer)
        
        destroyed = true
    }
    
    deinit {
        destroy()
    }
}
