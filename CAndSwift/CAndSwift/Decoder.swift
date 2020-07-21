import AVFoundation
import Accelerate
import ffmpeg

// Samples for a single frame
class FrameSamples {
    
    var rawByteArrays: [Data] = []
    var byteArrayPointers: [UnsafePointer<UInt8>] {rawByteArrays.compactMap {$0.withUnsafeBytes{$0}}}
    let sampleCount: Int32
    
    init(frame: UnsafeMutablePointer<AVFrame>) {
        
        let buffers = frame.pointee.datas()
        let linesize = Int(frame.pointee.linesize.0)
        
        for channelIndex in (0..<8) {
            
            guard let buffer = buffers[channelIndex] else {break}
            rawByteArrays.append(Data(bytes: buffer, count: linesize))
        }
        
        self.sampleCount = frame.pointee.nb_samples
    }
}

class DAudio {
    
    var frames: [FrameSamples] = []
    var floats: [Float] = []
    
    var sampleCount: Int32 = 0
    let maxSampleCount: Int32
    
    let sampleSize: Int
    let sampleFmt: AVSampleFormat
    
    var isFull: Bool {sampleCount >= maxSampleCount}
    
    init(maxSampleCount: Int32, sampleFmt: AVSampleFormat, sampleSize: Int) {
        
        self.maxSampleCount = maxSampleCount
        self.sampleFmt = sampleFmt
        self.sampleSize = sampleSize
    }
    
    func appendFrame(frame: UnsafeMutablePointer<AVFrame>) {
        
        self.sampleCount += frame.pointee.nb_samples
        frames.append(FrameSamples(frame: frame))
    }
    
    func constructAudioBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {

        guard sampleCount > 0 else {return nil}
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) {
            
            let numChannels = Int(format.channelCount)
            
            buffer.frameLength = buffer.frameCapacity
            let channels = buffer.floatChannelData
            
            var sampleCountSoFar: Int32 = 0
            
            for frame in frames {
                
                let frameSampleCount = Int(frame.sampleCount)
                let dataPointers = frame.byteArrayPointers
            
                for channelIndex in 0..<numChannels {

                    let bytesForChannel = dataPointers[channelIndex]
                    guard let channel = channels?[channelIndex] else {break}

                    switch sampleFmt {
                        
                    // Integer => scale to [-1, 1] and convert to Float.
                    case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:

                        var frameFloatsForChannel: [Float] = []
                        
                        switch sampleSize {

                        case 1:

                            // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                            let reboundData: UnsafePointer<Int8> = bytesForChannel.withMemoryRebound(to: Int8.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int8.max, frameSampleCount, byteOffset: -127)

                        case 2:

                            let reboundData: UnsafePointer<Int16> = bytesForChannel.withMemoryRebound(to: Int16.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int16.max, frameSampleCount)

                        case 4:

                            let reboundData: UnsafePointer<Int32> = bytesForChannel.withMemoryRebound(to: Int32.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int32.max, frameSampleCount)

                        case 8:

                            let reboundData: UnsafePointer<Int64> = bytesForChannel.withMemoryRebound(to: Int64.self, capacity: frameSampleCount){$0}
                            frameFloatsForChannel = convertToFloatArray(reboundData, Int64.max, frameSampleCount)

                        default: continue

                        }

                        if channelIndex < numChannels {
                            cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1)
                        } else {
                            vDSP_vadd(channel.advanced(by: Int(sampleCountSoFar)), 1, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1, vDSP_Length(frameSampleCount))
                        }

                    case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:

                        let frameFloatsForChannel: UnsafePointer<Float> = bytesForChannel.withMemoryRebound(to: Float.self, capacity: frameSampleCount){$0}
                        
                        if channelIndex < numChannels {
                            cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1)
                        } else {
                            vDSP_vadd(channel.advanced(by: Int(sampleCountSoFar)), 1, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1, vDSP_Length(frameSampleCount))
                        }

                    case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:

                        let doublesForChannel: UnsafePointer<Double> = bytesForChannel.withMemoryRebound(to: Double.self, capacity: frameSampleCount){$0}
                        let frameFloatsForChannel: [Float] = (0..<frameSampleCount).map {Float(doublesForChannel[$0])}
                        
                        if channelIndex < numChannels {
                            cblas_scopy(frame.sampleCount, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1)
                        } else {
                            vDSP_vadd(channel.advanced(by: Int(sampleCountSoFar)), 1, frameFloatsForChannel, 1, channel.advanced(by: Int(sampleCountSoFar)), 1, vDSP_Length(frameSampleCount))
                        }

                    default:

                        print("Invalid sample format", sampleFmt)
                    }
                }
                
                sampleCountSoFar += frame.sampleCount
            }
            
            return buffer
        }
        
        return nil
    }
    
    func convertToFloatArray<T>(_ unsafeArr: UnsafePointer<T>, _ maxSignedValue: T, _ numSamples: Int, byteOffset: T = 0) -> [Float] where T: SignedInteger {
        return (0..<numSamples).map {Float(Int64(unsafeArr[$0] + byteOffset)) / Float(maxSignedValue)}
    }
}

class Decoder {
    
    static func decodeAndPlay(_ file: URL) {
        
        guard setupFFmpeg(file) else {
            print("\nFFMpeg setup failure !")
            return
        }
        
        guard setupAudio() else {
            print("Audio Engine setup failed")
            return
        }
        
        eof = false
        
        decodeFrames(5)
        player.play()
        NSLog("Playback Started !\n")
        decodeFrames(5)
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
        
        sampleRate = audioContext!.pointee.sample_rate
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
    static var eof: Bool = false
    
    static func decodeFrames(_ seconds: Double = 10) {
        
        NSLog("Began decoding ... \(seconds) seconds of audio")
        
        var packet = AVPacket()
        var frame = AVFrame()
        let buffer: DAudio = DAudio(maxSampleCount: Int32(seconds * Double(sampleRate)), sampleFmt: sampleFmt, sampleSize: sampleSize)
        
        while !(buffer.isFull || eof) {
            
            guard 0 <= av_read_frame(formatContext, &packet) else {
                
                eof = true
                break
            }
            defer {
                av_packet_unref(&packet)
            }
            
            if packet.stream_index == audio_index, let ctx = audioContext {
                
                decode(ctx: ctx, packet: &packet, frame: &frame, buffer: buffer)
                av_frame_unref(&frame)
            }
            
            ctr += 1
        }
        
        if buffer.isFull || eof, let audioBuffer: AVAudioPCMBuffer = buffer.constructAudioBuffer(format: audioFormat) {
            
            player.scheduleBuffer(audioBuffer, {
                eof ? NSLog("Playback completed !!!\n") : decodeFrames()
            })
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
    
    static func decode(ctx: UnsafeMutablePointer<AVCodecContext>, packet: UnsafeMutablePointer<AVPacket>, frame: UnsafeMutablePointer<AVFrame>?, buffer: DAudio) {
        
        var ret: Int32 = 0
        
        ret = avcodec_send_packet(ctx, packet)
        if 0 > ret {
            
            print("err:", ret)
            return
        }
        
        av_packet_unref(packet)
        ret = avcodec_receive_frame(ctx, frame)
        
        while ret == 0, frame!.pointee.nb_samples > 0 {
            
            buffer.appendFrame(frame: frame!)
            ret = avcodec_receive_frame(ctx, frame)
        }
    }
    
    static var sampleRate: Int32!
    static var sampleFmt: AVSampleFormat!
    static var sampleSize: Int!
}

class Player {

    private let audioEngine: AVAudioEngine
    internal let playerNode: AVAudioPlayerNode

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        playerNode.volume = 1

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

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, _ completionHandler: AVAudioNodeCompletionHandler? = nil) {

        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler ?? {
            print("\nDONE playing buffer:", buffer.frameLength, buffer.frameCapacity)
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
