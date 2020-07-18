import Cocoa
import ffmpeg

class Reader {
    
    static func initialize() {
        
        av_register_all()
        avfilter_register_all()
    }
    
    static func readTrack(_ file: URL) -> TrackInfo? {
        
        var trackInfo: TrackInfo? = nil
        
        var chapters: [Chapter] = []
        
        var codecName: String = ""
        var duration: Double = 0
        var sampleRate: Double = 0
        var bitRate: Double = 0
        var channelCount: Int = 0
        var frames: Int64 = 0
        
        var metadata: [String: String] = [:]
        var coverArt: NSImage? = nil
        
        var formatContext = avformat_alloc_context()

        let err = avformat_open_input(&formatContext, file.path, nil, nil)
        if err == 0 {
            
            if avformat_find_stream_info(formatContext, nil) == 0, let ctx = formatContext?.pointee, let streams = ctx.streams {
                
                if let avChapters = ctx.chapters {
                 
                    let theChapters: [AVChapter] = (0..<ctx.nb_chapters).compactMap {avChapters.advanced(by: Int($0)).pointee?.pointee}
                        .sorted(by: {c1, c2 in c1.start < c2.start})
                    
                    var ctr: Int = 1
                    for chapter in theChapters {
                        
                        let conversionFactor: Double = Double(chapter.time_base.num) / Double(chapter.time_base.den)
                        let startTime = Double(chapter.start) * conversionFactor
                        let endTime = Double(chapter.end) * conversionFactor
                        let title = getMetadata(ptr: chapter.metadata)["title"] ?? "Chapter \(ctr)"
                        
                        chapters.append(Chapter(startTime: startTime, endTime: endTime, title: title))
                        
                        ctr += 1
                    }
                }
                
                // ---------- METADATA ---------------
                
                for (key, value) in getMetadata(ptr: ctx.metadata) {
                    metadata[key] = value
                }
                
                // -------------------------------------
                
                let theStreams: [AVStream] = (0..<ctx.nb_streams).compactMap {streams.advanced(by: Int($0)).pointee?.pointee}
                
                // Audio
                if let str = theStreams.filter({$0.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO}).first {
                    
                    duration = Double(str.duration * Int64(str.time_base.num)) / Double(str.time_base.den)
                    
                    let codecParams: AVCodecParameters = str.codecpar.pointee
                    
                    if let codec: AVCodec = avcodec_find_decoder(codecParams.codec_id)?.pointee {
                        
                        codecName = String(cString: codec.long_name)
                        sampleRate = Double(codecParams.sample_rate)
                        bitRate = Double(codecParams.bit_rate)
                        channelCount = Int(codecParams.channels)
                        frames = str.nb_frames == 0 ? Int64(sampleRate * duration) : str.nb_frames
                    }
                    
                    // ---------- METADATA ---------------
                    
                    for (key, value) in getMetadata(ptr: str.metadata) {
                        metadata[key] = value
                    }
                    
                    // -------------------------------------
                }
                
                // Album Art
                if let stream = theStreams.filter({$0.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO}).first {
                    coverArt = getCoverArt(formatCtx: ctx, stream: stream)
                }
            }
            
            trackInfo = TrackInfo(audioInfo: AudioInfo(codec: codecName, duration: duration, sampleRate: sampleRate, bitRate: bitRate,
                                                       channelCount: channelCount, frames: frames), metadata: metadata, art: coverArt, chapters: chapters)
        }
        else {
            print("\nERROR:", err)
        }
        
        avformat_close_input(&formatContext)
        avformat_free_context(formatContext)
        
        return trackInfo
    }
    
    private static func getMetadata(ptr: OpaquePointer!) -> [String: String] {
        
        var metadata: [String: String] = [:]
        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
        
        while let tag = av_dict_get(ptr, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
            
            metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
            tagPtr = tag
        }
        
        return metadata
    }
    
    private static func getCoverArt(formatCtx: AVFormatContext, stream: AVStream) -> NSImage? {
        
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
    
    static let dummy: AudioInfo = AudioInfo(codec: "SomeCodec", duration: 100, sampleRate: 44100, bitRate: 128, channelCount: 2, frames: 100000000)
}
