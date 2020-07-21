//import AVFoundation
//import Accelerate
//import ffmpeg
//
//class SlowScheduler: SchedulerProtocol {
//
//    var seekPosition: Double {0}
//
//    let player: Player
//    let playerNode: AVAudioPlayerNode
//
//    init(_ player: Player) {
//
//        self.player = player
//        self.playerNode = player.playerNode
//
//        oneTimeSetup()
//    }
//
//    // Variables required by ffmpeg
//
//    var formatContext: UnsafeMutablePointer<AVFormatContext>!
//    var codecContext: UnsafeMutablePointer<AVCodecContext>?
//    var audioStream: UnsafeMutablePointer<AVStream>?
//    var codec: UnsafeMutablePointer<AVCodec>?
//
//    var streamIndex: Int32 = -1
//    var format: AVAudioFormat!
//
//    var timeBase: AVRational!
//    var sampleRate: Int = 0
//    var duration: Double = 0
//
//    var got_frame: Int32 = 0
//    var length: Int32 = 0
//    var decodeFinished: Bool = false
//
//    var bufferedData: AudioFloatData = AudioFloatData()
//
//    private func oneTimeSetup() {
//        av_register_all()
//    }
//
//    private func setupForFile(_ file: URL) throws {
//
//        formatContext = avformat_alloc_context()
//        
//        let path = file.path
//        
//        if avformat_open_input(&formatContext, path, nil, nil) < 0 {
//            
//            print("Couldn't create format for \(path).")
//            throw AVError(AVError.operationNotAllowed)
//        }
//        
//        if avformat_find_stream_info(formatContext, nil) < 0 {
//            
//            print("Couldn't find stream information")
//            throw AVError(AVError.operationNotAllowed)
//        }
//        
//        streamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0)
//        if streamIndex == -1 {
//            
//            print("Couldn't find stream information")
//            throw AVError(AVError.operationNotAllowed)
//        }
//        
//        audioStream = formatContext?.pointee.streams.advanced(by: Int(streamIndex)).pointee
//        
//        if let stream = audioStream?.pointee {
//            
//            codecContext = avcodec_alloc_context3(codec)
//            avcodec_parameters_to_context(codecContext, stream.codecpar)
//            
//            if avcodec_open2(codecContext, codec, nil) < 0 {
//                
//                print("Couldn't open codec for \(String(cString: avcodec_get_name(codecContext?.pointee.codec_id ?? AV_CODEC_ID_NONE)))")
//                throw AVError(AVError.operationNotAllowed)
//            }
//            
//            format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(codecContext!.pointee.sample_rate), channels: AVAudioChannelCount(min (2, codecContext!.pointee.channels)), interleaved: false)
//            
//            // Print stream info
//            
//            print("---------- Audio Stream Info ----------\n")
//            print(String(format: "Stream Index:  %7d", streamIndex))
//            print(String(format: "Sample Format: %@", String(cString: av_get_sample_fmt_name(codecContext!.pointee.sample_fmt))))
//            print(String(format: "Sample Rate:   %7d", codecContext!.pointee.sample_rate))
//            print(String(format: "Sample Size:   %7d", av_get_bytes_per_sample(codecContext!.pointee.sample_fmt)))
//            print(String(format: "Channels:      %7d", codecContext!.pointee.channels))
//            print(String(format: "Planar ?:      %7d", av_sample_fmt_is_planar(codecContext!.pointee.sample_fmt)))
//        }
//    }
//    
//    private var swr: OpaquePointer!
//
//    private var stopped: Bool = false
//    
//    let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/swift-good-test.raw", "w+")
//
//    func scheduleOneBuffer(_ seconds: Double = 5) {
//        
//        var packet = AVPacket()
//        var frame = AVFrame()
//        //        var eof: Bool = false
//        
//        bufferedData.reset(Int(codecContext!.pointee.channels), Int(codecContext!.pointee.sample_rate), Int(seconds * Double(codecContext!.pointee.sample_rate)))
//        
//        while !bufferedData.isFull {
//            
//            guard 0 <= av_read_frame(formatContext, &packet) else {
//                break
//            }
//            
//            guard packet.stream_index == streamIndex, let ctx = codecContext else {
//                
//                av_packet_unref(&packet)
//                continue
//            }
//            
//            if avcodec_send_packet(ctx, &packet) == 0 {
//                av_packet_unref(&packet)
//                
//            } else {
//                return
//            }
//            
//            let ret = receiveAndHandle(ctx: ctx, frame: &frame)
//            
//            guard 0 <= ret else {
//                
////                print("ERROR:", ret)
//                continue
//            }
//            
//            av_frame_unref(&frame)
//        }
//        
//        if bufferedData.isFull {
//            
//            let numSamples = bufferedData.numSamples
//            
//            if let buffer: AVAudioPCMBuffer = createBuffer(channels: 2, audioFormat: format, numSamples: numSamples) {
//                
//                let data = buffer.floatChannelData
//
//                for s in 0..<numSamples {
//
//                    for i in 0..<bufferedData.channelCount {
//
//                        let sample = data![i][s]
//                        fwrite(&data![i][s], MemoryLayout<Float>.size, 1, outfile)
//                        ctr += 1
//                        
//                        if (ctr > 44100 && ctr < 44200) {
//                            print("\(ctr): \(sample)")
//                        }
//                    }
//                }
//                
////                player.scheduleBuffer(buffer, {
////
////                    print("\nDone playing buffer of size:", numSamples, ", continuing scheduling ...")
////
////                    if !self.stopped {
////
////                        let time = measureTime {
////                            self.scheduleOneBuffer()
////                        }
////
////                        print("Took \(time * 1000) msec to schedule buffer !")
////                    }
////                })
//            }
//        }
//        
//        fclose(outfile)
//    }
//
//    func receiveAndHandle(ctx: UnsafeMutablePointer<AVCodecContext>, frame: UnsafeMutablePointer<AVFrame>?) -> Int32 {
//        
//        var err: Int32 = avcodec_receive_frame(ctx, frame)
//        
//        while err == 0 {
//            
//            handleFrame(ctx: ctx.pointee, frame: frame!.pointee)
//            av_frame_unref(frame)
//            
//            err = avcodec_receive_frame(ctx, frame)
//        }
//        
//        return err
//    }
//    
//    func handleFrame(ctx: AVCodecContext, frame: AVFrame) {
//        
//        let fr = frame
//        print("\nHandling frame:", fr.channel_layout, fr.channels, fr.format, fr.linesize.0, fr.nb_samples, fr.pkt_duration, fr.pkt_size, fr.sample_rate)
//
//        // Resulting 2-D array of samples will always be in planar format (one buffer per channel)
//        var floats: [[Float]] = []
//        
//        let isPlanar: Bool = av_sample_fmt_is_planar(ctx.sample_fmt) == 1
//        
//        for _ in 0..<Int(ctx.channels) {
//            floats.append([])
//        }
//        
//        for sampleIndex in 0..<Int(frame.nb_samples) {
//        
//            for channelIndex in 0..<Int(ctx.channels) {
//            
//                var sample: Float
//                
//                if isPlanar {
//                    sample = getSample(ctx.sample_fmt, frame.extended_data[channelIndex], sampleIndex)
//                } else {
//                    sample = getSample(ctx.sample_fmt, frame.extended_data[0], (sampleIndex * Int(ctx.channels)) + channelIndex)
//                }
//                
//                floats[channelIndex].append(sample)
//                
////                fwrite(&sample, MemoryLayout<Float>.size, 1, outfile)
////                ctr += 1
////
////                if (ctr > 485100 && ctr < 485200) {
////                    print("\(ctr): \(sample)")
////                }
//            }
//        }
//        
//        bufferedData.appendFrame(floats)
//    }
//    
//    var ctr: Int = 0
//    
//    func getSample(_ format: AVSampleFormat, _ buffer: UnsafeMutablePointer<UInt8>?, _ sampleIndex: Int) -> Float {
//        
//        var val: Int64 = 0
//        var floatSample: Float = 0
//        let sampleSize: Int = Int(av_get_bytes_per_sample(format))
//        
//        switch format {
//            
//            case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:
//                
//                switch sampleSize {
//                    
//                case 1:
//                    
//                    // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
//                    val = Int64(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int8.self, capacity: 1){$0}[0]) - 127
//                    
//                case 2:
//                    
//                    val = Int64(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int16.self, capacity: 1){$0}[0])
//                    
//                case 4:
//                    
//                    val = Int64(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int32.self, capacity: 1){$0}[0])
//                    
//                case 8:
//                    
//                    val = buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int64.self, capacity: 1){$0}[0]
//                    
//                default: return 0
//                    
//                }
//                
//                // integer => Scale to [-1, 1] and convert to float.
//                let numSignedBits: Int64 = Int64(sampleSize) * 8 - 1
//                let signedMaxVal: Int64 = (1 << numSignedBits) - 1
//                
//                floatSample = Float(val) / Float(signedMaxVal)
//
//            case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
//                
//                // float => reinterpret
//                floatSample = buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Float.self, capacity: 1){$0}[0]
//
//            case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:
//                
//                // double => reinterpret and then static cast down
//                floatSample = Float(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Double.self, capacity: 1){$0}[0])
//
//            default:
//                
//                print("Invalid sample format", format)
//                return 0;
//        }
//        
//        return floatSample
//    }
//    
//    func createBuffer(channels numChannels: Int, audioFormat: AVAudioFormat, numSamples: Int) -> AVAudioPCMBuffer? {
//        
////        print("Scheduling buffer:", numSamples, "\n\n")
//        
//        if let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numSamples)) {
//            
//            buffer.frameLength = AVAudioFrameCount(numSamples)
//
//            let channels = buffer.floatChannelData
//            let floats = bufferedData.floats
//            
//            for i in 0..<numChannels {
//                
//                guard let channel = channels?[i] else {break}
//                cblas_scopy(Int32(numSamples), floats[i], 1, channel, 1)
//            }
//            
//            return buffer
//        }
//        
//        return nil
//    }
//    
//    func convertToFloatArray<T>(_ unsafeArr: UnsafePointer<T>, _ maxSignedValue: Int64, _ numSamples: Int, byteOffset: T = 0) -> [Float] where T: SignedInteger {
//        return (0..<numSamples).map {
//            
//            let sam = Float(Int64(unsafeArr[$0] + byteOffset)) / Float(maxSignedValue)
//            
////            if $0 < 44100 {
////                print("Sample \($0):", sam)
////            }
//            
//            return sam
//        }
//    }
//
//    func playTrack(_ file: URL, _ startPosition: Double = 0) {
//
//        stopped = true
//        if playerNode.isPlaying {playerNode.stop()}
//        stopped = false
//
//        do {
//            
//            try setupForFile(file)
//            
//            player.prepare(format)
//
//            let time = measureTime {
//                scheduleOneBuffer()
//            }
////            playerNode.play()
////
////            print("\n\nTook \(time * 1000) msec to schedule first buffer !")
////            print("Scheduler is playing file:", file.path, "!!! :D")
////
////            let t2 = measureTime {
////                scheduleOneBuffer() // "Look ahead" buffer to avoid gaps
////            }
////
////            print("Took \(t2 * 1000) msec to schedule second buffer !")
//            
//        } catch {
//            
//            print("Scheduler ERROR !")
//            return
//        }
//    }
//
//    func playLoop(_ file: URL, _ beginPlayback: Bool) {
//
//    }
//
//    func playLoop(_ file: URL, _ playbackStartTime: Double, _ beginPlayback: Bool) {
//
//    }
//
//    func endLoop(_ file: URL, _ loopEndTime: Double) {
//
//    }
//
//    func seekToTime(_ file: URL, _ seconds: Double, _ beginPlayback: Bool) {
//
//        stopped = true
//        if playerNode.isPlaying {playerNode.stop()}
//        stopped = false
//
//        av_seek_frame(formatContext, streamIndex, Int64(seconds * timeBase.reciprocal), AVSEEK_FLAG_FRAME)
//
//        scheduleOneBuffer()
//        scheduleOneBuffer()
//    }
//
//    func pause() {
//
//    }
//
//    func resume() {
//
//    }
//
//    func stop() {
//
//    }
//}
