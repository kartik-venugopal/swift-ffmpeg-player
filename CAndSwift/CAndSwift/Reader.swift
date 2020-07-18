import Foundation
import ffmpeg

class Reader {
    
    static func initialize() {
        
        av_register_all()
        avfilter_register_all()
    }
    
    static func readTrack(_ file: URL) -> TrackInfo? {
        
        var codecName: String = ""
        var duration: Double = 0
        var sampleRate: Double = 0
        var bitRate: Double = 0
        var channelCount: Int = 0
        var frames: Int64 = 0
        
        var metadata: [String: String] = [:]
        
        var formatContext = avformat_alloc_context()

        let err = avformat_open_input(&formatContext, file.path, nil, nil)
        if err == 0 {
            
            if avformat_find_stream_info(formatContext, nil) == 0, let ctx = formatContext?.pointee, let streams = ctx.streams {
                
                // ---------- METADATA ---------------
                
                var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
                
                while let tag = av_dict_get(ctx.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
                    
                    metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
                    tagPtr = tag
                }
                
                // -------------------------------------
                
                if ctx.iformat != nil {
                    print("\nCtx Input Format:", String(cString: ctx.iformat.pointee.name), String(cString: ctx.iformat.pointee.long_name))
                }
                
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
                    
                    var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
                    
                    while let tag = av_dict_get(str.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
                        
                        metadata[String(cString: tag.pointee.key)] = String(cString: tag.pointee.value)
                        tagPtr = tag
                    }
                    
                    // -------------------------------------
                }
                
                // Album Art
                if let str = theStreams.filter({$0.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO}).first {
                    
                    var codecParams: AVCodecParameters = str.codecpar.pointee
                    
                    if var codec: AVCodec = avcodec_find_decoder(codecParams.codec_id)?.pointee {
                        
                        if codec.name != nil {
                            
                            codecName = String(cString: codec.name)
                            print("Found Album Art of format:", codecName, "\n");
                        }
                        
                        let codecCtx: UnsafeMutablePointer<AVCodecContext>? = avcodec_alloc_context3(&codec)
                        avcodec_parameters_to_context(codecCtx, &codecParams)
                        avcodec_open2(codecCtx, &codec, nil)
                        
                        let packetPtr: UnsafeMutablePointer<AVPacket> = av_packet_alloc()
                        av_read_frame(formatContext, packetPtr)
                        
                        let fileDir = file.deletingLastPathComponent()
                        let filename = file.deletingPathExtension().lastPathComponent
                        let artFilePath = "\(filename)-albumArt.jpg"
                        
                        let image_file: UnsafeMutablePointer<FILE> = fopen(fileDir.appendingPathComponent(artFilePath).path, "wb")
                        _ = fwrite(packetPtr.pointee.data, Int(packetPtr.pointee.size), 1, image_file)
                        fclose(image_file)
                    }
                }
            }
            
            return TrackInfo(audioInfo: AudioInfo(codec: codecName, duration: duration, sampleRate: sampleRate, bitRate: bitRate, channelCount: channelCount, frames: frames), metadata: metadata)
        }
        else {
            
            print("\nERROR:", err)
            return nil
        }
    }
}

struct TrackInfo {
    
    var audioInfo: AudioInfo
    var metadata: [String: String]
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
