import AVFoundation
import Accelerate
import ffmpeg

struct AudioData {
    
    var datas: [Data] = []
    var linesizes: [Int] = []
    let samples: Int
    let timeStamp: Double
    
    init?(timeBase: AVRational, frame: UnsafeMutablePointer<AVFrame>) {
        
        self.samples = Int(frame.pointee.nb_samples)
        let buffers = frame.pointee.datas()
        for i in 0..<8 {
            guard let buffer = buffers[i] else {
                break
            }
            datas.append(Data(bytes: buffer, count: Int(frame.pointee.linesize.0)))
            linesizes.append(Int(frame.pointee.linesize.0))
        }
        
        if 0 == datas.count {
            return nil
        }
        
        self.timeStamp = Double(av_frame_get_best_effort_timestamp(frame)) * av_q2d(timeBase)
    }
}

class Decoder {
    
    static func decodeAndPlay(_ file: URL) {
        
        if setupFFmpeg(file) {
            print("\nFFMpeg setup success !!!")
        }
        
        guard setupAudio() else {
            print("Audio Engine setup failed")
            return
        }
        
        print("\nAudioEngine setup success !!!")

        decodeFrames()
    }
    
    static var formatContext: UnsafeMutablePointer<AVFormatContext>!
    
    static var audio_index: Int32 = -1
    static var audioStream: UnsafeMutablePointer<AVStream>?
    static var audioCodec: UnsafeMutablePointer<AVCodec>?
    static var audioContext: UnsafeMutablePointer<AVCodecContext>?
    
    private static func setupFFmpeg(_ file: URL) -> Bool {
        
        let path = file.path
        
        av_register_all()
        avfilter_register_all()
        formatContext = avformat_alloc_context()

        if avformat_open_input(&formatContext, file.path, nil, nil) < 0 {
            
            print("Couldn't create format for \(file.path)")
            return false
        }

        if avformat_find_stream_info(formatContext, nil) < 0 {
            
            print("Couldn't find stream information")
            return false
        }

        av_dump_format(formatContext, 0, path, 0)
        let duration = Double(formatContext!.pointee.duration + (formatContext!.pointee.duration <= Int64.max ? 5000 : 0)) / Double(AV_TIME_BASE)

        audio_index = av_find_best_stream(formatContext, AVMEDIA_TYPE_AUDIO, -1, -1, &audioCodec, 0)
        audioStream = formatContext?.pointee.streams.advanced(by: Int(audio_index)).pointee
        audioContext = avcodec_alloc_context3(audioCodec)
        avcodec_parameters_to_context(audioContext, audioStream?.pointee.codecpar)
        audioContext?.pointee.properties = audioStream?.pointee.codec.pointee.properties ?? 0
        audioContext?.pointee.qmin = audioStream?.pointee.codec.pointee.qmin ?? 0
        audioContext?.pointee.qmax = audioStream?.pointee.codec.pointee.qmax ?? 0
//        audioContext?.pointee.coded_width = audioStream?.pointee.codec.pointee.coded_width ?? 0
//        audioContext?.pointee.coded_height = audioStream?.pointee.codec.pointee.coded_height ?? 0
        audioContext?.pointee.time_base = audioStream?.pointee.time_base ?? AVRational()
        
//        audioQueue = AVFrameQueue(type: AVMEDIA_TYPE_AUDIO, queueCount: 128, time_base: , duration: duration)
        
        timeBase = audioContext!.pointee.time_base
        
        guard avcodec_open2(audioContext, audioCodec, nil) >= 0 else {
            
            print("Couldn't open codec for \(String(cString: avcodec_get_name(audioContext?.pointee.codec_id ?? AV_CODEC_ID_NONE)))")
            return false
        }
        
        return true
    }
    
    static var timeBase: AVRational!
    
    static var player: Player!
    
    static var audioFormat: AVAudioFormat!
    
    static func setupAudio() -> Bool {
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(audioStream!.pointee.codecpar.pointee.sample_rate), channels: AVAudioChannelCount(2), interleaved: false)
        
        player = Player()
        return true
    }
    
    static var got_frame: Int32 = 0
    static var length: Int32 = 0
    static var decodeFinished: Bool = false
    
    static func decodeFrames() {
        
        var packet = AVPacket()
        var frame = AVFrame()
        
        var ctr: Int = 0
        
        // 50 frames gives about 18 seconds of audio
        decode: while ctr < 50000 {
            
            guard 0 <= av_read_frame(formatContext, &packet) else {
                break decode
            }
            defer {
                av_packet_unref(&packet)
            }
            
            if packet.stream_index == audio_index, let ctx = audioContext {
                
                let ret = decode(ctx: ctx, packet: &packet, frame: &frame, got_frame: &got_frame, length: &length)
                
                guard 0 <= ret else {
                    
                    print("ERROR:", ret)
                    continue
                }
                defer {
                    av_frame_unref(&frame)
                }
                
                //                    audio.write(&frame)
                if let data = AudioData(timeBase: timeBase, frame: &frame) {
                    startAudioPlay(data)
                }
                
                ctr += 1
                
                if ctr % 10 == 0 {
                    print("\nDecoded frames:", ctr)
                }
            }
            
        }
        
        av_packet_unref(&packet)
        av_frame_unref(&frame)
        
        if 0 < avcodec_is_open(self.audioContext) {
            avcodec_close(self.audioContext)
        }
        avcodec_free_context(&self.audioContext)
        
        self.audioContext = nil
        
        avformat_close_input(&self.formatContext)
        avformat_free_context(self.formatContext)
        
        print("\nFINISHED decoding and scheduling frames :)\n")
    }
    
    static func decode(ctx: UnsafeMutablePointer<AVCodecContext>, packet: UnsafeMutablePointer<AVPacket>, frame: UnsafeMutablePointer<AVFrame>?, got_frame: inout Int32, length: inout Int32) -> Int32 {
        
        var ret: Int32 = 0
        got_frame = 0
        length = 0
        if ctx.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
            
            ret = avcodec_send_packet(ctx, packet)
            if 0 > ret {
                
                print("err:", ret)
                
                return ret < 0 ? 0 : ret
            }
            av_packet_unref(packet)
            ret = avcodec_receive_frame(ctx, frame)
            
            if 0 > ret {
//            if 0 > ret && ret != err2averr(ret) && 1 != is_eof(ret) {
                
                print("SHIT", ret)
                return ret
            }
            
            got_frame = 1
            length = frame?.pointee.pkt_size ?? 0
        }
        
        return ret
    }
    
    static var bufferCount: Int = 0
    
    static func startAudioPlay(_ aframe: AudioData) {
        
        let floatsLen = aframe.linesizes[0] / MemoryLayout<Float>.size
        let datas: [UnsafePointer<UInt8>] = aframe.datas.flatMap(){$0.withUnsafeBytes(){$0}}
        
        if let buffer: AVAudioPCMBuffer = createBuffer(channels: 2, format: audioFormat, audioDatas: datas, floatsLength: floatsLen, samples: aframe.samples) {
            
            if bufferCount == 0 {
                player.prepare(buffer.format)
            }
            
            player.scheduleBuffer(buffer)
            
            if bufferCount == 0 {
                player.play()
            }
            
            bufferCount += 1
        }
    }
    
    static func createBuffer(channels numChannels: Int, format: AVAudioFormat, audioDatas datas: [UnsafePointer<UInt8>], floatsLength: Int, samples: Int) -> AVAudioPCMBuffer? {
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(floatsLength)) {
            
            buffer.frameLength = AVAudioFrameCount(samples)
            let channels = buffer.floatChannelData
            
            for i in 0..<datas.count {
                
                let data = datas[i]
                guard let channel = channels?[i % numChannels] else {
                    break
                }
                
                let floats = data.withMemoryRebound(to: Float.self, capacity: floatsLength){$0}
                if i < numChannels {
                    cblas_scopy(Int32(floatsLength), floats, 1, channel, 1)
                } else {
                    vDSP_vadd(channel, 1, floats, 1, channel, 1, vDSP_Length(floatsLength))
                }
            }
            
            return buffer
        }
        
        return nil
    }
}

class Player {
    
    private let audioEngine: AVAudioEngine
    internal let playerNode: AVAudioPlayerNode
    internal let timeNode: AVAudioUnitVarispeed
    
    init() {
        
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        timeNode = AVAudioUnitVarispeed()
        
        timeNode.rate = 1
        playerNode.volume = 0.75
        
        audioEngine.attach(playerNode)
        audioEngine.attach(timeNode)
        
        audioEngine.connect(playerNode, to: timeNode, format: nil)
        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: nil)
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("\nERROR starting audio engine")
        }
    }
    
    func prepare(_ format: AVAudioFormat) {
        
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(timeNode)
        
        audioEngine.connect(playerNode, to: timeNode, format: format)
        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: format)
    }
    
    func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        
        playerNode.scheduleBuffer(buffer, completionHandler: {
            print("\nDONE !", buffer.frameLength, buffer.frameCapacity)
        })
    }
    
    func play() {
        playerNode.play()
    }
}

extension AVFrame {
    
    mutating func datas() -> [UnsafeMutablePointer<UInt8>?] {
        let ptr = UnsafeBufferPointer(start: self.extended_data, count: 8)
        let arr = Array(ptr)
        return arr
    }
    
    var lines: UnsafeMutablePointer<Int32> {
        var tuple = self.linesize
        let tuple_ptr = withUnsafeMutablePointer(to: &tuple){$0}
        let line_ptr = tuple_ptr.withMemoryRebound(to: Int32.self, capacity: 8){$0}
        return line_ptr
    }
}
