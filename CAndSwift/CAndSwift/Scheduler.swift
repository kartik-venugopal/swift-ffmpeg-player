import AVFoundation
import Accelerate
import ffmpeg

class Scheduler: SchedulerProtocol {

    var seekPosition: Double {0}

    let player: Player
    let playerNode: AVAudioPlayerNode

    init(_ player: Player) {

        self.player = player
        self.playerNode = player.playerNode

        oneTimeSetup()
    }

    // Variables required by ffmpeg

    var formatContext: UnsafeMutablePointer<AVFormatContext>!
    var audioContext: UnsafeMutablePointer<AVCodecContext>?
    var audioStream: UnsafeMutablePointer<AVStream>?
    var codec: UnsafeMutablePointer<AVCodec>?

    var streamIndex: Int32 = -1
    var format: AVAudioFormat!

    var timeBase: AVRational!
    var sampleRate: Int = 0
    var duration: Double = 0

    var got_frame: Int32 = 0
    var length: Int32 = 0
    var decodeFinished: Bool = false

    var bufferedData: AudioData = AudioData()

    private func oneTimeSetup() {

        av_register_all()
        avfilter_register_all()
    }

    private func setupForFile(_ file: URL) -> Bool {

        if let theAudioContext = self.audioContext {

            if 0 < avcodec_is_open(theAudioContext) {
                avcodec_close(theAudioContext)
            }

            avcodec_free_context(&self.audioContext)
            self.audioContext = nil
        }

        if let theFormatContext = self.formatContext {

            avformat_close_input(&self.formatContext)
            avformat_free_context(theFormatContext)
        }

        formatContext = avformat_alloc_context()

        let path = file.path

        if avformat_open_input(&formatContext, path, nil, nil) < 0 {

            print("Couldn't create format for \(path).")
            return false
        }

        if avformat_find_stream_info(formatContext, nil) < 0 {

            print("Couldn't find stream information")
            return false
        }

        av_dump_format(formatContext, 0, path, 0)
        streamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0)
        audioStream = formatContext?.pointee.streams.advanced(by: Int(streamIndex)).pointee

        if let stream = audioStream?.pointee {
            
            audioContext = avcodec_alloc_context3(codec)
            
            avcodec_parameters_to_context(audioContext, stream.codecpar)
            
            timeBase = stream.time_base
            duration = Double(stream.duration) * timeBase.ratio
            sampleRate = Int(stream.codecpar.pointee.sample_rate)

            print("\nTimeBase:", timeBase.num, timeBase.den, duration, sampleRate)

            print("\nChannelCount:", stream.codecpar.pointee.channels)
            format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: AVAudioChannelCount(2), interleaved: false)
            
//            if audioContext?.pointee.sample_fmt == AV_SAMPLE_FMT_S16P {
//
//               audioContext?.pointee.sample_fmt = AV_SAMPLE_FMT_S32P
//                print("\n*** CHANGED FMT to:", audioContext?.pointee.sample_fmt)
//            }
            
            print("\n\nCur FORMAT:", audioContext!.pointee.sample_fmt.rawValue)
            print("IsPlanar ?", av_sample_fmt_is_planar(audioContext!.pointee.sample_fmt))
            print("PackedFormat -", av_get_packed_sample_fmt(audioContext!.pointee.sample_fmt))
        }

        if avcodec_open2(audioContext, codec, nil) < 0 {

//            print("Couldn't open codec for \(String(cString: avcodec_get_name(audioContext?.pointee.codec_id ?? AV_CODEC_ID_NONE)))")
            return false
        }

        return true
    }
    
    private var swr: OpaquePointer!

    private var stopped: Bool = false

    func scheduleOneBuffer() {

        var packet = AVPacket()
        var frame = AVFrame()

        bufferedData.reset(sampleRate)

        // 50 frames gives about 18 seconds of audio
        while !bufferedData.isFull {

            guard 0 <= av_read_frame(formatContext, &packet) else {
                return
            }

            defer {
                av_packet_unref(&packet)
            }

            if packet.stream_index == streamIndex, let ctx = audioContext {

                let ret = decode(ctx: ctx, packet: &packet, frame: &frame, got_frame: &got_frame, length: &length)

                guard 0 <= ret else {

                    print("ERROR:", ret)
                    continue
                }

                defer {
                    av_frame_unref(&frame)
                }

                bufferedData.appendFrame(&frame)
            }
        }
        
        if bufferedData.isFull {

            let floatsLen = bufferedData.lineSizes[0] / MemoryLayout<Float>.size
            let datas: [UnsafePointer<UInt8>] = bufferedData.datas.flatMap(){$0.withUnsafeBytes(){$0}}
            
            // Resample if required
//            _ = Resampler.resample(bufferedData)
            
            if let buffer: AVAudioPCMBuffer = createBuffer(channels: 2, format: format, audioDatas: datas, floatsLength: floatsLen, samples: bufferedData.numSamples) {
                player.scheduleBuffer(buffer, {

                    print("\nDone playing buffer of size:", floatsLen, ", continuing scheduling ...")

                    if !self.stopped {
                        self.scheduleOneBuffer()
                    }
                })
            }
        }
    }

    func createBuffer(channels numChannels: Int, format: AVAudioFormat, audioDatas datas: [UnsafePointer<UInt8>], floatsLength: Int, samples: Int) -> AVAudioPCMBuffer? {
        
        print("Scheduling buffer:", numChannels, datas.count, floatsLength, samples, "\n\n")

        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples)) {
//        let fmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: format.sampleRate, channels: format.channelCount, interleaved: false)!
//        if let buffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(samples)) {

            buffer.frameLength = AVAudioFrameCount(samples)
            
            // Float Planar samples
            
            let channels = buffer.floatChannelData

            for i in 0..<datas.count {

                let data = datas[i]
                guard let channel = channels?[i % numChannels] else {break}

                let floats = data.withMemoryRebound(to: Float.self, capacity: floatsLength){$0}

//                cblas_scopy(Int32(floatsLength), floats, 1, channel, 1)
                memcpy(channel, floats, samples * MemoryLayout<Float>.size)
            }
            
            // S16P samples
            
//            let channels = buffer.int16ChannelData
//
//            for i in 0..<datas.count {
//
//                let data = datas[i]
//                guard let channel = channels?[i % numChannels] else {break}
//
////                let floats = data.withMemoryRebound(to: Float.self, capacity: floatsLength){$0}
//                if i < numChannels {
//
////                    cblas_scopy(Int32(floatsLength), data, 1, channel, 1)
//                    memcpy(channel, data, samples * MemoryLayout<Int16>.size)
//
//                } else {
////                    vDSP_vadd(channel, 1, floats, 1, channel, 1, vDSP_Length(floatsLength))
//                }
//            }

            return buffer
        }

        return nil
    }
    
    func decode(ctx: UnsafeMutablePointer<AVCodecContext>, packet: UnsafeMutablePointer<AVPacket>,
                frame: UnsafeMutablePointer<AVFrame>?, got_frame: inout Int32, length: inout Int32) -> Int32 {

        var ret: Int32 = 0
        got_frame = 0
        length = 0
        
        if ctx.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
            
            ret = avcodec_send_packet(ctx, packet)
            
            if 0 > ret {

                print("err:", ret)
                return ret < 0 ? 0 : ret
            }
            
//            let sz: Int32 = av_get_bytes_per_sample(ctx.pointee.sample_fmt)

            av_packet_unref(packet)
            ret = avcodec_receive_frame(ctx, frame)
            
            print("Frame:", frame!.pointee.channels, frame!.pointee.format)

            if 0 > ret {
                //            if 0 > ret && ret != err2averr(ret) && 1 != is_eof(ret) {
                print("SHIT", ret)
                return ret
            }

            got_frame = 1
            length = frame?.pointee.pkt_size ?? 0
            
            print("PktSize:", length)
        }

        return ret
    }

    func playTrack(_ file: URL, _ startPosition: Double = 0) {

        stopped = true
        if playerNode.isPlaying {playerNode.stop()}
        stopped = false

        if !setupForFile(file) {
            return
        }

        player.prepare(format)

        scheduleOneBuffer()
        scheduleOneBuffer() // "Look ahead" buffer to avoid gaps
        
        playerNode.play()

        print("Scheduler is playing file:", file.path, "!!! :D")
    }

    func playLoop(_ file: URL, _ beginPlayback: Bool) {

    }

    func playLoop(_ file: URL, _ playbackStartTime: Double, _ beginPlayback: Bool) {

    }

    func endLoop(_ file: URL, _ loopEndTime: Double) {

    }

    func seekToTime(_ file: URL, _ seconds: Double, _ beginPlayback: Bool) {

        stopped = true
        if playerNode.isPlaying {playerNode.stop()}
        stopped = false

        av_seek_frame(formatContext, streamIndex, Int64(seconds * timeBase.reciprocal), AVSEEK_FLAG_FRAME)

        scheduleOneBuffer()
        scheduleOneBuffer()
    }

    func pause() {

    }

    func resume() {

    }

    func stop() {

    }
}

extension AVRational {

    var ratio: Double {Double(num) / Double(den)}
    var reciprocal: Double {Double(den) / Double(num)}
}
