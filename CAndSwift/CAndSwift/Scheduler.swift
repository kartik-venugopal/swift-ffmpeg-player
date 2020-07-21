//import AVFoundation
//import Accelerate
//import ffmpeg
//
//class Scheduler: SchedulerProtocol {
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
//    var bufferedData: AudioData = AudioData()
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
//            format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(codecContext!.pointee.sample_rate), channels: AVAudioChannelCount(min(2, codecContext!.pointee.channels)), interleaved: false)
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
//    let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/swift-test.raw", "w+")
//
//    func scheduleOneBuffer(_ seconds: Double = 15) {
//
//        var packet = AVPacket()
//        var frame = AVFrame()
//        //        var eof: Bool = false
//
//        bufferedData.reset(Int(codecContext!.pointee.channels), Int(seconds * Double(codecContext!.pointee.sample_rate)))
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
//            if ctx.pointee.codec_type == AVMEDIA_TYPE_AUDIO {
//
//                var ret = avcodec_send_packet(ctx, &packet)
//                if 0 > ret {
//
//                    print("err:", ret)
//                    continue
//                }
//
//                av_packet_unref(&packet)
//                ret = avcodec_receive_frame(ctx, &frame)
//
//                if 0 > ret {
//
//                    print("SHIT", ret)
//                    continue
//                }
//
//                print("\nHandling frame:", frame.channel_layout, frame.channels, frame.format, frame.linesize.0, frame.nb_samples, frame.pkt_duration, frame.pkt_size, frame.sample_rate)
//                bufferedData.appendFrame(&frame)
//            }
//
//            av_frame_unref(&frame)
//        }
//
//        if bufferedData.isFull {
//
//            let floatsLen = bufferedData.lineSize / MemoryLayout<Float>.size
//            let datas: [UnsafePointer<UInt8>] = bufferedData.datas.flatMap(){$0.withUnsafeBytes(){$0}}
//
//            // Resample if required
////            _ = Resampler.resample(bufferedData)
//
//            let numSamples = bufferedData.numSamples
//            var ctr: Int = 0
//
//            if let buffer: AVAudioPCMBuffer = createBuffer(channels: bufferedData.channelCount, audioFormat: format, audioDatas: datas, samples: numSamples, linesize: floatsLen) {
//
////                let data = buffer.floatChannelData
////
////                for s in 0..<numSamples {
////
////                    for i in 0..<bufferedData.channelCount {
////
////                        let sample = data![i][s]
////                        fwrite(&data![i][s], MemoryLayout<Float>.size, 1, outfile)
////                        ctr += 1
////
//////                        if (ctr > 44100 && ctr < 44200) {
//////                            print("\(ctr): \(sample)")
//////                        }
////                    }
////                }
//
//                player.scheduleBuffer(buffer, {
//
//                    print("\nDone playing buffer of size:", numSamples, ", continuing scheduling ...")
//
//                    if !self.stopped {
//
////                        let time = measureTime {
//                            self.scheduleOneBuffer()
////                        }
//
////                        print("\n\nTook \(time * 1000) msec to RECURSIVELY schedule buffer !")
//                    }
//                })
//            }
//        }
//
//        fclose(outfile)
//    }
//
//    func createBuffer(channels numChannels: Int, audioFormat: AVAudioFormat, audioDatas datas: [UnsafePointer<UInt8>], samples: Int, linesize: Int) -> AVAudioPCMBuffer? {
//
//        print("Scheduling buffer:", numChannels, datas.count, samples, "\n\n")
//
//        if let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(linesize)) {
//
//            buffer.frameLength = AVAudioFrameCount(samples)
//
//            let channels = buffer.floatChannelData
//            for i in 0..<datas.count {
//
//                let data = datas[i]
//
//                guard let channel = channels?[i % numChannels] else {
//                    break
//                }
//
//                let floats = data.withMemoryRebound(to: Float.self, capacity: samples){$0}
//
//                if i < numChannels {
//                    cblas_scopy(Int32(samples), floats, 1, channel, 1)
//
//                } else {
//
//                    // Downmixing :D
//                    vDSP_vadd(channel, 1, floats, 1, channel, 1, vDSP_Length(samples))
//                }
//            }
//
////            // integer => Scale to [-1, 1] and convert to float.
////            let sampleFmt: AVSampleFormat = codecContext!.pointee.sample_fmt
////            let sampleSize: Int = Int(av_get_bytes_per_sample(sampleFmt))
////            let numSignedBits: Int64 = Int64(sampleSize) * 8 - 1
////            let signedMaxVal: Int64 = (1 << numSignedBits) - 1
////
////            let channels = buffer.floatChannelData
////
////            for i in 0..<numChannels {
////
////                let data = datas[i]
////                guard let channel = channels?[i] else {break}
////
////                switch sampleFmt {
////
////                case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:
////
////                    var floatsForChannel: [Float] = []
////
////                    switch sampleSize {
////
////                    case 1:
////
////                        // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
////                        let reboundData: UnsafePointer<Int8> = data.withMemoryRebound(to: Int8.self, capacity: samples){$0}
////                        floatsForChannel = convertToFloatArray(reboundData, signedMaxVal, samples, byteOffset: -127)
////
////                    case 2:
////
////                        let reboundData: UnsafePointer<Int16> = data.withMemoryRebound(to: Int16.self, capacity: samples){$0}
////                        floatsForChannel = convertToFloatArray(reboundData, signedMaxVal, samples)
////
////                    case 4:
////
////                        let reboundData: UnsafePointer<Int32> = data.withMemoryRebound(to: Int32.self, capacity: samples){$0}
////                        floatsForChannel = convertToFloatArray(reboundData, signedMaxVal, samples)
////
////                    case 8:
////
////                        let reboundData: UnsafePointer<Int64> = data.withMemoryRebound(to: Int64.self, capacity: samples){$0}
////                        floatsForChannel = convertToFloatArray(reboundData, signedMaxVal, samples)
////
////                    default: continue
////
////                    }
////
//////                    memcpy(channel, floatsForChannel, samples * MemoryLayout<Float>.size)
////                    cblas_scopy(Int32(samples), floatsForChannel, 1, channel, 1)
////
////                case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
////
////                    let floatsForChannel: UnsafePointer<Float> = data.withMemoryRebound(to: Float.self, capacity: samples){$0}
//////                    memcpy(channel, floatsForChannel, samples * MemoryLayout<Float>.size)
////                    cblas_scopy(Int32(samples), floatsForChannel, 1, channel, 1)
////
////                case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:
////
////                    let doublesForChannel: UnsafePointer<Double> = data.withMemoryRebound(to: Double.self, capacity: samples){$0}
////                    let floatsForChannel: [Float] = (0..<samples).map {Float(doublesForChannel[$0])}
////                    memcpy(channel, floatsForChannel, samples * MemoryLayout<Float>.size)
////
////                default:
////
////                    print("Invalid sample format", sampleFmt)
////                }
////            }
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
//                scheduleOneBuffer(5)
//            }
//            playerNode.play()
//
//            print("\n\nTook \(time * 1000) msec to schedule first buffer !")
//            print("Scheduler is playing file:", file.path, "!!! :D")
////
////            let t2 = measureTime {
////                scheduleOneBuffer(5) // "Look ahead" buffer to avoid gaps
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
//
//class AudioData {
//
//    var datas: [Data] = []
//    var lineSize: Int = 0
//
//    var channelCount: Int = 0
//    var numFrames: Int = 0
//    var numSamples: Int = 0
//    var maxSamples: Int = 0
//
//    var isFull: Bool {self.numFrames > 0 && numSamples > maxSamples}
//
//    func reset(_ channelCount: Int, _ maxSamples: Int) {
//
//        self.datas.removeAll()
//
//        self.channelCount = channelCount
//        self.maxSamples = maxSamples
//
//        self.numSamples = 0
//        self.numFrames = 0
//
//        self.lineSize = 0
//    }
//
//    func appendFrame(_ frame: UnsafeMutablePointer<AVFrame>) {
//
//        let buffers = frame.pointee.datas()
//
//        numSamples += Int(frame.pointee.nb_samples)
//
//        for i in 0..<self.channelCount {
//            
//            guard let buffer = buffers[i] else {
//                break
//            }
//
//            if numFrames == 0 {
//
//                datas.append(Data(bytes: buffer, count: Int(frame.pointee.linesize.0)))
//                lineSize = Int(frame.pointee.linesize.0)
//
//            } else {
//
//                datas[i].append(contentsOf: Data(bytes: buffer, count: Int(frame.pointee.linesize.0)))
//                lineSize += Int(frame.pointee.linesize.0)
//            }
//        }
//
//        numFrames += 1
//
//        print("NOW BUFFERED-AUDIO-DATA:", numFrames, numSamples, "/" , maxSamples, lineSize, datas.count, datas[0].count, isFull)
//    }
//}
//
//extension AVRational {
//
//    var ratio: Double {Double(num) / Double(den)}
//    var reciprocal: Double {Double(den) / Double(num)}
//}
