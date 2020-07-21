import AVFoundation
import Accelerate
import ffmpeg

struct DAudio {
    
    var datas: [Data] = []
    let samples: Int
    
    var dataPointers: [UnsafePointer<UInt8>] {datas.compactMap {$0.withUnsafeBytes{$0}}}
    
    init?(frame: UnsafeMutablePointer<AVFrame>) {
        
        self.samples = Int(frame.pointee.nb_samples)
        let buffers = frame.pointee.datas()
        let linesize = Int(frame.pointee.linesize.0)
        
        for i in 0..<8 {
            
            guard let buffer = buffers[i] else {
                break
            }
            
            datas.append(Data(bytes: buffer, count: linesize))
        }
        
        if datas.isEmpty {return nil}
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
//        let duration = Double(formatContext!.pointee.duration + (formatContext!.pointee.duration <= Int64.max ? 5000 : 0)) / Double(AV_TIME_BASE)

        audio_index = av_find_best_stream(formatContext, AVMEDIA_TYPE_AUDIO, -1, -1, &audioCodec, 0)
        audioStream = formatContext?.pointee.streams.advanced(by: Int(audio_index)).pointee
        audioContext = avcodec_alloc_context3(audioCodec)
        avcodec_parameters_to_context(audioContext, audioStream?.pointee.codecpar)
        audioContext?.pointee.time_base = audioStream?.pointee.time_base ?? AVRational()
        
        timeBase = audioContext!.pointee.time_base
        
        guard avcodec_open2(audioContext, audioCodec, nil) >= 0 else {
            
            print("Couldn't open codec for \(String(cString: avcodec_get_name(audioContext?.pointee.codec_id ?? AV_CODEC_ID_NONE)))")
            return false
        }
        
        sampleFmt = audioContext!.pointee.sample_fmt
        sampleSize = Int(av_get_bytes_per_sample(sampleFmt))
        
        return true
    }
    
    static var timeBase: AVRational!
    
    static var player: Player!
    
    static var audioFormat: AVAudioFormat!
    
    static func setupAudio() -> Bool {
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(audioStream!.pointee.codecpar.pointee.sample_rate), channels: AVAudioChannelCount(2), interleaved: false)
        
        player = Player()
        player.prepare(audioFormat)
        
        return true
    }
    
    static var decodeFinished: Bool = false
    
    static var ctr: Int = 0
    
    static func decodeFrames() {
        
        NSLog("Began decoding ...")
        
        var packet = AVPacket()
        var frame = AVFrame()
        var eof: Bool = false
        
        decode: while ctr < 500000 && !eof {
            
            guard 0 <= av_read_frame(formatContext, &packet) else {
                
                eof = true
                break decode
            }
            defer {
                av_packet_unref(&packet)
            }
            
            if packet.stream_index == audio_index, let ctx = audioContext {
                
                decode(ctx: ctx, packet: &packet, frame: &frame)
                av_frame_unref(&frame)
            }
        }
        
        if eof {
            
            NSLog("Reached EOF !!!")
            
            av_packet_unref(&packet)
            av_frame_unref(&frame)
            
            if 0 < avcodec_is_open(self.audioContext) {
                avcodec_close(self.audioContext)
            }
            avcodec_free_context(&self.audioContext)
            
            self.audioContext = nil
            
            avformat_close_input(&self.formatContext)
            avformat_free_context(self.formatContext)
        }
    }
    
    static func decode(ctx: UnsafeMutablePointer<AVCodecContext>, packet: UnsafeMutablePointer<AVPacket>, frame: UnsafeMutablePointer<AVFrame>?) {
        
        var ret: Int32 = 0
        
        ret = avcodec_send_packet(ctx, packet)
        if 0 > ret {
            
            print("err:", ret)
            return
        }
        
        av_packet_unref(packet)
        
        repeat {
            
            ret = avcodec_receive_frame(ctx, frame)
            
            if let adata = DAudio(frame: frame!),
                let buffer: AVAudioPCMBuffer = createBuffer(channels: 2, format: audioFormat, audioDatas: adata.dataPointers, samples: adata.samples) {
                
                player.scheduleBuffer(buffer)
                
                if !player.playerNode.isPlaying {
                    player.play()
                }
                
            }
            
        } while ret == 0
    }
    
    static var sampleFmt: AVSampleFormat!
    static var sampleSize: Int!
    
    static func createBuffer(channels numChannels: Int, format: AVAudioFormat, audioDatas dataPointers: [UnsafePointer<UInt8>], samples: Int) -> AVAudioPCMBuffer? {
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples)) {
            
            buffer.frameLength = AVAudioFrameCount(samples)
            let channels = buffer.floatChannelData
            
            for i in 0..<numChannels {

                let bytesForChannel = dataPointers[i]
                guard let channel = channels?[i] else {break}

                switch sampleFmt {
                    
                // Integer => scale to [-1, 1] and convert to Float.
                case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:

                    var floatsForChannel: [Float] = []
                    
                    switch sampleSize {

                    case 1:

                        // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                        let reboundData: UnsafePointer<Int8> = bytesForChannel.withMemoryRebound(to: Int8.self, capacity: samples){$0}
                        floatsForChannel = convertToFloatArray(reboundData, Int8.max, samples, byteOffset: -127)

                    case 2:

                        let reboundData: UnsafePointer<Int16> = bytesForChannel.withMemoryRebound(to: Int16.self, capacity: samples){$0}
                        floatsForChannel = convertToFloatArray(reboundData, Int16.max, samples)

                    case 4:

                        let reboundData: UnsafePointer<Int32> = bytesForChannel.withMemoryRebound(to: Int32.self, capacity: samples){$0}
                        floatsForChannel = convertToFloatArray(reboundData, Int32.max, samples)

                    case 8:

                        let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: samples){$0}
                        floatsForChannel = convertToFloatArray(reboundData, Int64.max, samples)

                    default: continue

                    }

                    cblas_scopy(Int32(samples), floatsForChannel, 1, channel, 1)

                case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:

                    let floatsForChannel: UnsafePointer<Float> = bytesForChannel.withMemoryRebound(to: Float.self, capacity: samples){$0}
                    cblas_scopy(Int32(samples), floatsForChannel, 1, channel, 1)

                case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:

                    let doublesForChannel: UnsafePointer<Double> = bytesForChannel.withMemoryRebound(to: Double.self, capacity: samples){$0}
                    let floatsForChannel: [Float] = (0..<samples).map {Float(doublesForChannel[$0])}
                    cblas_scopy(Int32(samples), floatsForChannel, 1, channel, 1)

                default:

                    print("Invalid sample format", sampleFmt)
                }
            }
            
            return buffer
        }
        
        return nil
    }
    
    static func convertToFloatArray<T>(_ unsafeArr: UnsafePointer<T>, _ maxSignedValue: T, _ numSamples: Int, byteOffset: T = 0) -> [Float] where T: SignedInteger {
        return (0..<numSamples).map {Float(Int64(unsafeArr[$0] + byteOffset)) / Float(maxSignedValue)}
    }
}

class Player {

    private let audioEngine: AVAudioEngine
    internal let playerNode: AVAudioPlayerNode

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        playerNode.volume = 0.5

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print("\nERROR starting audio engine")
        }
    }

    func prepare(_ format: AVAudioFormat) {

        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
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
