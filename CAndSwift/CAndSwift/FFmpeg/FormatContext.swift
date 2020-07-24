import Foundation
import ffmpeg

class FormatContext {

    let file: URL
    let filePath: String
    
    var pointer: UnsafeMutablePointer<AVFormatContext>?
    let avContext: AVFormatContext
    
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
        
        let fileOpenResult: Int32 = avformat_open_input(&pointer, file.path, nil, nil)
        
        if fileOpenResult >= 0, let pointee = pointer?.pointee {
            self.avContext = pointee
            
        } else {
            
            print("\nFormatContext.init(): Unable to open file '\(filePath)'. Error: \(errorString(errorCode: fileOpenResult))")
            return nil
        }
        
        let resultCode: Int32 = avformat_find_stream_info(pointer, nil)
        if resultCode < 0 {
            
            print("\nFormatContext.init(): Unable to find stream info for file '\(filePath)'. Error: \(errorString(errorCode: resultCode))")
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

        let readResult: Int32 = av_read_frame(pointer, packet.pointer)
        guard readResult >= 0 else {
            
            print("\nFormatContext.readPacket(): Unable to read packet. Error: \(readResult) (\(errorString(errorCode: readResult)))")
            throw PacketReadError(readResult)
        }
        
        return packet.streamIndex == stream.index ? packet : nil
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

    func destroy() {
        
        avformat_close_input(&pointer)
        avformat_free_context(pointer)
    }
}
