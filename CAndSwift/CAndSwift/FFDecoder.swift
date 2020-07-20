import AVFoundation
import ffmpeg

class FFDecoder {
    
    var formatContext: UnsafeMutablePointer<AVFormatContext>!
    var codecContext: UnsafeMutablePointer<AVCodecContext>?
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
    
    var bufferedData: AudioFloatData = AudioFloatData()
    
    let outfile: UnsafeMutablePointer<FILE> = fopen("/Volumes/MyData/Music/Aural-Test/swift-test.raw", "w+")
    
    init() {
        oneTimeSetup()
    }
    
    private func oneTimeSetup() {
        av_register_all()
    }
    
    func initForFile(_ file: URL) throws {
        
        formatContext = avformat_alloc_context()
        
        let path = file.path
        
        if avformat_open_input(&formatContext, path, nil, nil) < 0 {
            
            print("Couldn't create format for \(path).")
            throw AVError(AVError.operationNotAllowed)
        }
        
        if avformat_find_stream_info(formatContext, nil) < 0 {
            
            print("Couldn't find stream information")
            throw AVError(AVError.operationNotAllowed)
        }
        
        streamIndex = av_find_best_stream(formatContext, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0)
        if streamIndex == -1 {
            
            print("Couldn't find stream information")
            throw AVError(AVError.operationNotAllowed)
        }
        
        audioStream = formatContext?.pointee.streams.advanced(by: Int(streamIndex)).pointee
        
        if let stream = audioStream?.pointee {
            
            codecContext = avcodec_alloc_context3(codec)
            avcodec_parameters_to_context(codecContext, stream.codecpar)
            
            if avcodec_open2(codecContext, codec, nil) < 0 {
                
                print("Couldn't open codec for \(String(cString: avcodec_get_name(codecContext?.pointee.codec_id ?? AV_CODEC_ID_NONE)))")
                throw AVError(AVError.operationNotAllowed)
            }
            
            // Print stream info
            
            print("---------- Audio Stream Info ----------\n")
            print(String(format: "Stream Index:  %7d", streamIndex))
            print(String(format: "Sample Format: %@", String(cString: av_get_sample_fmt_name(codecContext!.pointee.sample_fmt))))
            print(String(format: "Sample Rate:   %7d", codecContext!.pointee.sample_rate))
            print(String(format: "Sample Size:   %7d", av_get_bytes_per_sample(codecContext!.pointee.sample_fmt)))
            print(String(format: "Channels:      %7d", codecContext!.pointee.channels))
            print(String(format: "Planar ?:      %7d", av_sample_fmt_is_planar(codecContext!.pointee.sample_fmt)))
        }
    }
    
    func decodeNSeconds(_ seconds: Double = 15) {
        
        var packet = AVPacket()
        var frame = AVFrame()
//        var eof: Bool = false
        
        bufferedData.reset(Int(codecContext!.pointee.channels), Int(codecContext!.pointee.sample_rate), Int(seconds * Double(codecContext!.pointee.sample_rate)))
        
        while !bufferedData.isFull {
            
            guard 0 <= av_read_frame(formatContext, &packet) else {
                break
            }
            
            guard packet.stream_index == streamIndex, let ctx = codecContext else {
                
                av_packet_unref(&packet)
                continue
            }
            
            if avcodec_send_packet(ctx, &packet) == 0 {
                av_packet_unref(&packet)
                
            } else {
                return
            }
                
            let ret = receiveAndHandle(ctx: ctx, frame: &frame)
            
            guard 0 <= ret else {

                print("ERROR:", ret)
                continue
            }
            
            av_frame_unref(&frame)
        }
        
        if bufferedData.isFull {
            
            // Return buffer
//            var sms = bufferedData.floats
            
//            print("\nAbout to write: \(sms.count) x \(sms[0].count) values")
//
////            for sampleIndex in 0..<Int(frame.nb_samples) {
//                for sampleIndex in 0..<sms[0].count {
//
//                for channelIndex in 0..<Int(codecContext!.pointee.channels) {
//                    fwrite(&sms[channelIndex][sampleIndex], MemoryLayout<Float>.size, 1, outfile)
//                }
//            }
        }
        
        fclose(outfile)
    }
    
    func receiveAndHandle(ctx: UnsafeMutablePointer<AVCodecContext>, frame: UnsafeMutablePointer<AVFrame>?) -> Int32 {
        
        var err: Int32 = avcodec_receive_frame(ctx, frame)
        
        while err == 0 {
            
            handleFrame(ctx: ctx.pointee, frame: frame!.pointee)
            av_frame_unref(frame)
            
            err = avcodec_receive_frame(ctx, frame)
        }
        
        return err
    }
    
    func handleFrame(ctx: AVCodecContext, frame: AVFrame) {
        
        let fr = frame
        print("\nHandling frame:", fr.channel_layout, fr.channels, fr.format, fr.linesize.0, fr.nb_samples, fr.pkt_duration, fr.pkt_size, fr.sample_rate, "\n")

        // Resulting 2-D array of samples will always be in planar format (one buffer per channel)
        var floats: [[Float]] = []
        
        let isPlanar: Bool = av_sample_fmt_is_planar(ctx.sample_fmt) == 1
        
        for _ in 0..<Int(ctx.channels) {
            floats.append([])
        }
        
        for sampleIndex in 0..<Int(frame.nb_samples) {
        
            for channelIndex in 0..<Int(ctx.channels) {
            
                var sample: Float
                
                if isPlanar {
                    sample = getSample(ctx.sample_fmt, frame.extended_data[channelIndex], sampleIndex)
                } else {
                    sample = getSample(ctx.sample_fmt, frame.extended_data[0], (sampleIndex * Int(ctx.channels)) + channelIndex)
                }
                
                floats[channelIndex].append(sample)
                
                fwrite(&sample, MemoryLayout<Float>.size, 1, outfile)
                ctr += 1
                
                if (ctr > 485100 && ctr < 485200) {
                    print("\(ctr): \(sample)")
                }
            }
        }
        
        bufferedData.appendFrame(floats)
    }
    
    var ctr: Int = 0
    
    func getSample(_ format: AVSampleFormat, _ buffer: UnsafeMutablePointer<UInt8>?, _ sampleIndex: Int) -> Float {
        
        var val: Int64 = 0
        var floatSample: Float = 0
        let sampleSize: Int = Int(av_get_bytes_per_sample(format))
        
        switch format {
            
            case AV_SAMPLE_FMT_U8, AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_U8P, AV_SAMPLE_FMT_S16P, AV_SAMPLE_FMT_S32P:
                
                switch sampleSize {
                    
                case 1:
                    
                    // Subtract 127 to make the unsigned byte signed (8-bit samples are always unsigned)
                    val = Int64(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int8.self, capacity: 1){$0}[0]) - 127
                    
                case 2:
                    
                    val = Int64(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int16.self, capacity: 1){$0}[0])
                    
                case 4:
                    
                    val = Int64(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int32.self, capacity: 1){$0}[0])
                    
                case 8:
                    
                    val = buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Int64.self, capacity: 1){$0}[0]
                    
                default: return 0
                    
                }
                
                // integer => Scale to [-1, 1] and convert to float.
                let numSignedBits: Int64 = Int64(sampleSize) * 8 - 1
                let signedMaxVal: Int64 = (1 << numSignedBits) - 1
                
                floatSample = Float(val) / Float(signedMaxVal)

            case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
                
                // float => reinterpret
                floatSample = buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Float.self, capacity: 1){$0}[0]

            case AV_SAMPLE_FMT_DBL, AV_SAMPLE_FMT_DBLP:
                
                // double => reinterpret and then static cast down
                floatSample = Float(buffer!.advanced(by: sampleIndex * sampleSize).withMemoryRebound(to: Double.self, capacity: 1){$0}[0])

            default:
                
                print("Invalid sample format", format)
                return 0;
        }
        
        return floatSample
    }
}

class AudioFloatData {
    
    var floats: [[Float]] = []
    var lineSize: Int = 0
    
    var channelCount: Int = 0
    var sampleRate: Int = 0
    
    var numFrames: Int = 0
    var numSamples: Int = 0
    var maxSamples: Int = 0
    
    // Hold up to 5 seconds of samples in one object
    //    var isFull: Bool {self.numFrames > 0 && self.numSamples >= 5 * sampleRate}
    var isFull: Bool {self.numFrames > 0 && self.numSamples > self.maxSamples}
    
    func reset(_ channelCount: Int, _ sampleRate: Int, _ maxSamples: Int) {
        
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        
        self.maxSamples = maxSamples
        self.numSamples = 0
        self.numFrames = 0
        
        self.floats.removeAll()
        for _ in 1...channelCount {
            self.floats.append([])
        }
        
        self.lineSize = 0
    }
    
    static var frames: Int = 0
    
    func appendFrame(_ frameFloats: [[Float]]) {
        
        let frameSampleCount = frameFloats[0].count
        self.numSamples += frameSampleCount
        
        for i in 0..<channelCount {
            
            for j in 0..<frameSampleCount {
                
                self.floats[i].append(frameFloats[i][j])
            }
        }
        
        numFrames += 1
        
        print("\nNOW BUFFERED-AUDIO-DATA:", numFrames, numSamples, sampleRate, lineSize, floats[0].count, isFull)
        
        Self.frames += 1
    }
}
