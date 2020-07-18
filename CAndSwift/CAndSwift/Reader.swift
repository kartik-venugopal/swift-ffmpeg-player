import Cocoa
import ffmpeg

class Reader {
    
    static func initialize() {
        
        av_register_all()
        avfilter_register_all()
    }
    
    static func readTrack(_ file: URL) -> TrackInfo? {
        
        var trackInfo: TrackInfo? = nil
        var audioInfo: AudioInfo? = nil
        
        var chapters: [Chapter] = []
        
        var metadata: [String: String] = [:]
        var coverArt: NSImage? = nil
        
        var formatContext = avformat_alloc_context()

        let err = avformat_open_input(&formatContext, file.path, nil, nil)
        if err == 0 {
            
            if avformat_find_stream_info(formatContext, nil) == 0, let ctx = formatContext?.pointee, let streams = ctx.streams {
                
                if let avChapters = ctx.chapters {
                    chapters = readChapters(avChapters, Int(ctx.nb_chapters))
                }
                
                // ---------- METADATA ---------------
                
                for (key, value) in readMetadata(ptr: ctx.metadata) {
                    metadata[key] = value
                }
                
                // -------------------------------------
                
                let theStreams: [AVStream] = (0..<ctx.nb_streams).compactMap {streams.advanced(by: Int($0)).pointee?.pointee}
                
                // Audio
                if let stream = theStreams.filter({$0.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO}).first {
                    
                    let audioStreamInfo = readAudioInfo(stream)
                    audioInfo = audioStreamInfo.audioInfo
                    
                    for (key, value) in audioStreamInfo.metadata {
                        metadata[key] = value
                    }
                }
                
                // Album Art
                if let stream = theStreams.filter({$0.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO}).first {
                    coverArt = readCoverArt(formatCtx: ctx, stream: stream)
                }
            }
            
            trackInfo = TrackInfo(audioInfo: audioInfo ?? AudioInfo.dummy, metadata: metadata, art: coverArt, chapters: chapters)
        }
        else {
            print("\nERROR:", err)
        }
        
        avformat_close_input(&formatContext)
        avformat_free_context(formatContext)
        
        return trackInfo
    }
    
    private static func readAudioInfo(_ stream: AVStream) -> (audioInfo: AudioInfo, metadata: [String: String]) {
        
        var codecName: String = ""
        var duration: Double = 0
        var sampleRate: Double = 0
        var bitRate: Double = 0
        var channelCount: Int = 0
        var frames: Int64 = 0
        
        var metadata: [String: String] = [:]
        
        duration = Double(stream.duration * Int64(stream.time_base.num)) / Double(stream.time_base.den)
        
        let codecParams: AVCodecParameters = stream.codecpar.pointee
        
        if let codec: AVCodec = avcodec_find_decoder(codecParams.codec_id)?.pointee {
            
            codecName = String(cString: codec.long_name)
            sampleRate = Double(codecParams.sample_rate)
            bitRate = Double(codecParams.bit_rate)
            channelCount = Int(codecParams.channels)
            frames = stream.nb_frames == 0 ? Int64(sampleRate * duration) : stream.nb_frames
        }
        
        // ---------- METADATA ---------------
        
        for (key, value) in readMetadata(ptr: stream.metadata) {
            metadata[key] = value
        }
        
        // -------------------------------------
        
        return (AudioInfo(codec: codecName, duration: duration, sampleRate: sampleRate, bitRate: bitRate,
                          channelCount: channelCount, frames: frames), metadata)
    }
    
    private static func readChapters(_ avChapters: UnsafeMutablePointer<UnsafeMutablePointer<AVChapter>?>, _ numChapters: Int) -> [Chapter] {
        
        var chapters: [Chapter] = []
        
        let theChapters: [AVChapter] = (0..<numChapters).compactMap {avChapters.advanced(by: $0).pointee?.pointee}
            .sorted(by: {c1, c2 in c1.start < c2.start})
        
        var ctr: Int = 1
        for chapter in theChapters {
            
            let conversionFactor: Double = Double(chapter.time_base.num) / Double(chapter.time_base.den)
            let startTime = Double(chapter.start) * conversionFactor
            let endTime = Double(chapter.end) * conversionFactor
            let title = readMetadata(ptr: chapter.metadata)["title"] ?? "Chapter \(ctr)"
            
            chapters.append(Chapter(startTime: startTime, endTime: endTime, title: title))
            
            ctr += 1
        }
        
        return chapters
    }
    
    private static func readMetadata(ptr: OpaquePointer!) -> [String: String] {
        
        var metadata: [String: String] = [:]
        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
        
        while let tag = av_dict_get(ptr, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
            
            metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            tagPtr = tag
        }
        
        return metadata
    }
    
    private static func readCoverArt(formatCtx: AVFormatContext, stream: AVStream) -> NSImage? {
        
        var ctx: AVFormatContext = formatCtx
        var codecParams: AVCodecParameters = stream.codecpar.pointee
        
        if var codec: AVCodec = avcodec_find_decoder(codecParams.codec_id)?.pointee {
            
            let codecCtx: UnsafeMutablePointer<AVCodecContext>? = avcodec_alloc_context3(&codec)
            avcodec_parameters_to_context(codecCtx, &codecParams)
            avcodec_open2(codecCtx, &codec, nil)
            
            let packetPtr: UnsafeMutablePointer<AVPacket> = av_packet_alloc()
            av_read_frame(&ctx, packetPtr)
            
            if packetPtr.pointee.data != nil, packetPtr.pointee.size > 0 {
                
                let data: Data = Data(bytes: packetPtr.pointee.data, count: Int(packetPtr.pointee.size))
                return NSImage(data: data)
            }
            
            av_packet_unref(packetPtr)
        }
        
        return nil
    }
}

struct TrackInfo {
    
    var audioInfo: AudioInfo
    var metadata: [String: String]
    var art: NSImage?
    var chapters: [Chapter]
}

struct Chapter {
    
    var startTime: Double
    var endTime: Double
    var title: String
}

struct AudioInfo {
    
    var codec: String
    var duration: Double
    var sampleRate: Double
    var bitRate: Double
    var channelCount: Int
    var frames: Int64
    
    static let dummy: AudioInfo = AudioInfo(codec: "<Unknown>", duration: 0, sampleRate: 0, bitRate: 0, channelCount: 0, frames: 0)
}
