import AVFoundation
import ffmpeg

class Decoder {
    
    static func decodeAndPlay(_ file: URL) {
        
        do {
            try setupForFile(file)
            
        } catch {
            
            print("\nFFmpeg / audio engine setup failure !")
            return
        }
        
        eof = false
        
        decodeFrames(5)
        player.play()
        NSLog("Playback Started !\n")
        
        decodeFrames(5)
    }
    
    static var formatCtx: UnsafeMutablePointer<AVFormatContext>!
    
    static var streamIndex: Int32 = -1
    static var stream: UnsafeMutablePointer<AVStream>!
    
    static var codec: UnsafeMutablePointer<AVCodec>!
    static var codecCtx: UnsafeMutablePointer<AVCodecContext>!
    
    private static func setupForFile(_ file: URL) throws {
        
        formatCtx = avformat_alloc_context()
        
        let path = file.path
        
        if avformat_open_input(&formatCtx, path, nil, nil) < 0 {
            
            print("Couldn't create format for \(path).")
            throw AVError(AVError.operationNotAllowed)
        }
        
        if avformat_find_stream_info(formatCtx, nil) < 0 {
            
            print("Couldn't find stream information")
            throw AVError(AVError.operationNotAllowed)
        }
        
        streamIndex = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0)
        if streamIndex == -1 {
            
            print("Couldn't find stream information")
            throw AVError(AVError.operationNotAllowed)
        }
        
        stream = formatCtx.pointee.streams.advanced(by: Int(streamIndex)).pointee
        
        if let theStream = stream?.pointee {
            
            codecCtx = avcodec_alloc_context3(codec)
            avcodec_parameters_to_context(codecCtx, theStream.codecpar)
            
            if avcodec_open2(codecCtx, codec, nil) < 0 {
                
                print("Couldn't open codec for \(String(cString: avcodec_get_name(codecCtx.pointee.codec_id)))")
                throw AVError(AVError.operationNotAllowed)
            }
            
            sampleRate = codecCtx.pointee.sample_rate
            sampleFmt = codecCtx.pointee.sample_fmt
            sampleSize = Int(av_get_bytes_per_sample(sampleFmt))
            
            // Print stream info
            
            print("---------- Audio Stream Info ----------\n")
            print(String(format: "Stream Index:  %7d", streamIndex))
            print(String(format: "Sample Format: %7@", String(cString: av_get_sample_fmt_name(sampleFmt))))
            print(String(format: "Sample Rate:   %7d", sampleRate))
            print(String(format: "Sample Size:   %7d", av_get_bytes_per_sample(sampleFmt)))
            print(String(format: "Channels:      %7d", codecCtx.pointee.channels))
            print(String(format: "Planar ?:      %7@", String(av_sample_fmt_is_planar(sampleFmt) == 1)))
        }
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: AVAudioChannelCount(2), interleaved: false)
        
        player = Player()
        player.prepare(audioFormat)
    }
    
    static var timeBase: AVRational!
    
    static var player: Player!
    
    static var audioFormat: AVAudioFormat!
    static var eof: Bool = false
    
    static func decodeFrames(_ seconds: Double = 10) {
        
        NSLog("Began decoding ... \(seconds) seconds of audio")
        
        var packet = AVPacket()
        var frame = AVFrame()
        let buffer: SamplesBuffer = SamplesBuffer(maxSampleCount: Int32(seconds * Double(sampleRate)), sampleFmt: sampleFmt, sampleSize: sampleSize)
        
        while !(buffer.isFull || eof) {
            
            guard 0 <= av_read_frame(formatCtx, &packet) else {
                
                eof = true
                break
            }
            defer {
                av_packet_unref(&packet)
            }
            
            if packet.stream_index == streamIndex, let ctx = codecCtx {
                
                decode(ctx: ctx, packet: &packet, frame: &frame, buffer: buffer)
                av_frame_unref(&frame)
            }
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
            
            if 0 < avcodec_is_open(self.codecCtx) {
                avcodec_close(self.codecCtx)
            }
            avcodec_free_context(&self.codecCtx)
            
            self.codecCtx = nil
            
            avformat_close_input(&self.formatCtx)
            avformat_free_context(self.formatCtx)
        }
    }
    
    static func decode(ctx: UnsafeMutablePointer<AVCodecContext>, packet: UnsafeMutablePointer<AVPacket>, frame: UnsafeMutablePointer<AVFrame>?, buffer: SamplesBuffer) {
        
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
    internal let timeNode: AVAudioUnitVarispeed

    init() {

        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        timeNode = AVAudioUnitVarispeed()
        timeNode.rate = 1
        
        playerNode.volume = 1

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

    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, _ completionHandler: AVAudioNodeCompletionHandler? = nil) {

        playerNode.scheduleBuffer(buffer, completionHandler: completionHandler ?? {
            print("\nDONE playing buffer:", buffer.frameLength, buffer.frameCapacity)
        })
    }

    func play() {
        playerNode.play()
    }
    
    
    //
    //    init() {
    //
    //        audioEngine = AVAudioEngine()
    //        playerNode = AVAudioPlayerNode()
    
    //        playerNode.volume = 0.5
    //
    //        audioEngine.attach(playerNode)
//            audioEngine.attach(timeNode)
    //
    //        audioEngine.connect(playerNode, to: timeNode, format: nil)
    //        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: nil)
    //
    //        audioEngine.prepare()
    //
    //        do {
    //            try audioEngine.start()
    //        } catch {
    //            print("\nERROR starting audio engine")
    //        }
    //    }
    //
    //    func prepare(_ format: AVAudioFormat) {
    //
    //        audioEngine.disconnectNodeOutput(playerNode)
    //        audioEngine.disconnectNodeOutput(timeNode)
    //
    //        audioEngine.connect(playerNode, to: timeNode, format: format)
    //        audioEngine.connect(timeNode, to: audioEngine.mainMixerNode, format: format)
    //    }
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
