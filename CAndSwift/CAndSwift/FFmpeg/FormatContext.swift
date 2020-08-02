import Foundation

class FormatContext {

    let file: URL
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    var avContext: AVFormatContext {pointer!.pointee}
    
    var mediaTypes: [AVMediaType]
    
    private var shouldReadAudioStream: Bool {mediaTypes.contains(AVMEDIA_TYPE_AUDIO)}
    private var shouldReadImageStream: Bool {mediaTypes.contains(AVMEDIA_TYPE_VIDEO)}
    
    var streams: [Stream]
    var streamCount: Int {streams.count}
    
    var audioStream: AudioStream? {
        shouldReadAudioStream ? streams.compactMap {$0 as? AudioStream}.first : nil
    }
    
    var imageStream: ImageStream? {
        shouldReadImageStream ? streams.compactMap {$0 as? ImageStream}.first : nil
    }
    
    var metadata: [String: String] {
        readMetadata(ptr: avContext.metadata)
    }
    
    var bitRate: Int64 {avContext.bit_rate}
    
    var duration: Double {
        audioStream?.duration ?? estimatedDuration ?? bruteForceDuration ?? 0
    }
    
    private lazy var estimatedDuration: Double? = {
        avContext.duration > 0 ? (Double(avContext.duration) / Double(AV_TIME_BASE)) : nil
    }()
    
    private lazy var bruteForceDuration: Double? = {
        DurationEstimationContext(file)?.duration
    }()
    
    lazy var fileSize: UInt64 = {
        
        do {
            
            let attr = try FileManager.default.attributesOfItem(atPath: filePath)
            return attr[FileAttributeKey.size] as? UInt64 ?? 0
            
        } catch let error as NSError {
            
            NSLog("Error getting size of file '%@': %@", filePath, error.description)
            return 0
        }
    }()
    
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
    
    init?(_ file: URL, _ mediaTypes: [AVMediaType] = [AVMEDIA_TYPE_AUDIO, AVMEDIA_TYPE_VIDEO]) {
        
        self.file = file
        self.filePath = file.path
        
        self.pointer = avformat_alloc_context()
        
        self.mediaTypes = mediaTypes
        
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
                    
                case AVMEDIA_TYPE_AUDIO:    return shouldReadAudioStream ? AudioStream(pointer) : nil
                    
                case AVMEDIA_TYPE_VIDEO:    return shouldReadImageStream ? ImageStream(pointer) : nil
                    
                default:                    return nil
                    
                }
            }
        }
    }
    
    func readPacket(_ stream: Stream) throws -> Packet? {
        
        let packet = try Packet(pointer)
        return packet.streamIndex == stream.index ? packet : nil
    }
    
    func seekWithinStream(_ stream: AudioStream, targetByte: Int64) throws {
        
        stream.codec.flushBuffers()
        
        print("\nSeeking ... byte: \(targetByte) / \(fileSize)")
        
        // Track playback completed. Send EOF code.
        if targetByte >= fileSize {
            throw SeekError(EOF_CODE)
        }
        
        let seekResult: ResultCode = av_seek_frame(pointer, stream.index, targetByte, AVSEEK_FLAG_BYTE)
        
        guard seekResult.isNonNegative else {

            print("\nFormatContext.seekWithinStream(byte): Unable to seek within stream \(stream.index). Error: \(seekResult) (\(seekResult.errorDescription)))")
            throw SeekError(seekResult)
        }
    }
    
    func seekWithinStream(_ stream: AudioStream, targetFrame: Int64) throws {
        
        stream.codec.flushBuffers()
        
        // Track playback completed. Send EOF code.
        if targetFrame >= stream.frameCount {
            throw SeekError(EOF_CODE)
        }
        
        let seekResult: ResultCode = av_seek_frame(pointer, stream.index, targetFrame, AVSEEK_FLAG_BACKWARD)
        
        guard seekResult.isNonNegative else {

            print("\nFormatContext.seekWithinStream(frame): Unable to seek within stream \(stream.index). Error: \(seekResult) (\(seekResult.errorDescription)))")
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
