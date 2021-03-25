

// --------------

//import Foundation
//
/////
///// Encapsulates a context for reading audio data / metadata from a single audio file using ffmpeg.
/////
///// Instantiates, provides, and manages the life cycles of several member objects through which several ffmpeg functions can be executed.
/////
//class MetadataEditingContext {
//
//    //    ///
//    //    /// A context representing the file's container format.
//    //    /// Used to obtain streams and read (coded) packets.
//    //    ///
//    //    let format: FormatContext
//    //
//    //    ///
//    //    /// The first / best audio stream in the file.
//    //    ///
//    //    /// # Note #
//    //    ///
//    //    /// This property provides the convenience of accessing the audio stream within **format**.
//    //    /// The same AudioStream may be obtained by calling **format.audioStream**.
//    //    ///
//    //    let audioStream: AudioStream
//    //
//    //    ///
//    //    /// The codec used to decode packets read from the audio stream.
//    //    ///
//    //    let audioCodec: AudioCodec
//    //
//    //    ///
//    //    /// The (optional) video stream that contains cover art, if present. Nil otherwise.
//    //    ///
//    //    let imageStream: ImageStream?
//
//    var inFormatContext: UnsafeMutablePointer<AVFormatContext>?
//
//    var outFormatContext: UnsafeMutablePointer<AVFormatContext>?
//
//    let out_filename: String
//
//    var title: String? {
//
//        didSet {
//            av_dict_set(&outFormatContext!.pointee.metadata, "TIT2", title, 0)
//        }
//    }
//
//    var artist: String? {
//
//        didSet {
//            av_dict_set(&outFormatContext!.pointee.metadata, "TPE1", artist, 0)
//        }
//    }
//
//    var album: String? {
//
//        didSet {
//            av_dict_set(&outFormatContext!.pointee.metadata, "TALB", album, 0)
//        }
//    }
//
//    var genre: String? {
//
//        didSet {
//            av_dict_set(&outFormatContext!.pointee.metadata, "TCON", genre, 0)
//        }
//    }
//
//    ///
//    /// Attempts to construct an AudioFileContext instance for the given file.
//    ///
//    /// - Parameter file: The audio file to be read / decoded by this context.
//    ///
//    /// Fails (returns nil) if:
//    ///
//    /// - An error occurs while opening the file or reading (demuxing) its streams.
//    /// - No audio stream is found in the file.
//    /// - No suitable codec is found for the audio stream.
//    ///
//    /// # Note #
//    ///
//    /// If this initializer succeeds (does not return nil), it indicates that the file being read:
//    ///
//    /// 1. Is a valid media file.
//    /// 2. Has at least one audio stream.
//    /// 3. Is able to decode that audio stream.
//    ///
//    init?(forFile file: URL) {
//
//        var ofmt: UnsafeMutablePointer<AVOutputFormat>? = nil
//        var ifmt_ctx: UnsafeMutablePointer<AVFormatContext>? = nil
//        var ofmt_ctx: UnsafeMutablePointer<AVFormatContext>? = nil
//
//        var pkt: UnsafeMutablePointer<AVPacket>? = nil
//
//        let in_filename: String = file.path
//        self.out_filename = "/Users/kven/Music/TagEdit/tagEditOut-\(Int.random(in: 1000..<1000000)).mp3"
//
//        var ret: Int32
//
//        var stream_index: Int = 0;
//        var stream_mapping: UnsafeMutablePointer<Int>? = nil
//        var stream_mapping_size: Int = 0
//
//        ret = avformat_open_input(&ifmt_ctx, in_filename, nil, nil)
//        if ret < 0 {
//
//            print("Could not open input file '%s'", in_filename)
//            return nil
//        }
//
//        ret = avformat_find_stream_info(ifmt_ctx, nil)
//        if ret < 0 {
//
//            print("Failed to retrieve input stream information");
//            return nil
//        }
//
//        av_dump_format(ifmt_ctx, 0, in_filename, 0)
//
//        avformat_alloc_output_context2(&ofmt_ctx, nil, nil, out_filename)
//
//        if ofmt_ctx == nil {
//
//            print("Could not create output context\n");
////            ret = AVERROR_UNKNOWN
////            goto end;
//        }
//
//        stream_mapping_size = Int(ifmt_ctx!.pointee.nb_streams)
//        stream_mapping = UnsafeMutablePointer<Int>(OpaquePointer(av_mallocz_array(stream_mapping_size, MemoryLayout<UnsafeMutablePointer<Int>>.size)))
//
////        if stream_mapping == nil {
////            ret = AVERROR(ENOMEM);
////            goto end;
////        }
//
//        ofmt = ofmt_ctx!.pointee.oformat
//
//        for i in 0..<Int(ifmt_ctx!.pointee.nb_streams) {
//
//            var out_stream: UnsafeMutablePointer<AVStream>?
//            let in_stream: UnsafeMutablePointer<AVStream>? = ifmt_ctx!.pointee.streams[i]
//
//            let in_codecpar: UnsafeMutablePointer<AVCodecParameters> = in_stream!.pointee.codecpar
//            let codec_type: AVMediaType = in_codecpar.pointee.codec_type
//
//            if codec_type != AVMEDIA_TYPE_AUDIO &&
//                codec_type != AVMEDIA_TYPE_VIDEO &&
//                codec_type != AVMEDIA_TYPE_SUBTITLE {
//
//                stream_mapping![i] = -1
//                continue
//            }
//
//            stream_mapping![i] = stream_index
//            stream_index += 1
//
//            out_stream = avformat_new_stream(ofmt_ctx, nil)
//
//            if out_stream == nil {
//
//                print("Failed allocating output stream\n")
////                ret = AVERROR_UNKNOWN;
////                goto end;
//            }
//
//            ret = avcodec_parameters_copy(out_stream!.pointee.codecpar, in_codecpar)
//            if ret < 0 {
//
//                print("Failed to copy codec parameters\n")
////                goto end;
//            }
//
//            out_stream!.pointee.codecpar.pointee.codec_tag = 0
//        }
//
//        av_dump_format(ofmt_ctx, 0, out_filename, 1)
//
////        if ofmt!.pointee.flags & AVFMT_NOFILE == 0 {
//
//            ret = avio_open(&ofmt_ctx!.pointee.pb, out_filename, AVIO_FLAG_WRITE)
//
//            if ret < 0 {
//
//                print("Could not open output file '%s'", out_filename)
////                    goto end;
//            }
////        }
//
//        ret = avformat_write_header(ofmt_ctx, nil)
//        if ret < 0 {
//            print("Error occurred when opening output file\n")
////            goto end;
//        }
//
//        var packet: UnsafeMutablePointer<AVPacket> = av_packet_alloc()
//
//        while true {
//
//            var in_stream: UnsafeMutablePointer<AVStream>
//            var out_stream: UnsafeMutablePointer<AVStream>
//
//            ret = av_read_frame(ifmt_ctx, packet)
//
//            if (ret < 0) {
//                break
//            }
//
//            in_stream = ifmt_ctx!.pointee.streams[Int(packet.pointee.stream_index)]!
//
//            if (packet.pointee.stream_index >= stream_mapping_size ||
//                    stream_mapping![Int(packet.pointee.stream_index)] < 0) {
//
//                av_packet_unref(packet)
//                continue
//            }
//
//            packet.pointee.stream_index = Int32(stream_mapping![Int(packet.pointee.stream_index)])
//
//            out_stream = ofmt_ctx!.pointee.streams[Int(packet.pointee.stream_index)]!
//
////            log_packet(ifmt_ctx, &pkt, "in");
//
//            /* copy packet */
//
////            pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream!.pointee.time_base, out_stream!.pointee.time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
////            pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream!.pointee.time_base, out_stream!.pointee.time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
////            pkt.duration = av_rescale_q(pkt.duration, in_stream!.pointee.time_base, out_stream!.pointee.time_base);
////            pkt.pos = -1;
////            log_packet(ofmt_ctx, &pkt, "out");
//
//            ret = av_interleaved_write_frame(ofmt_ctx, packet)
//            if (ret < 0) {
//
//                print("Error muxing packet\n")
//                break
//            }
//
//            av_packet_unref(packet)
//        }
//
//        av_write_trailer(ofmt_ctx)
//
//        avformat_close_input(&ifmt_ctx)
//
//        /* close output */
//
//        if ofmt_ctx != nil && ofmt!.pointee.flags & AVFMT_NOFILE == 0 {
//            avio_closep(&ofmt_ctx!.pointee.pb)
//        }
//
//        avformat_free_context(ofmt_ctx)
//        av_freep(&stream_mapping)
//
//        if (ret < 0 && ret != ERROR_EOF) {
//
//            print("Error occurred: %s\n", ret.errorDescription);
//        }
//    }
//
//    func save() {
//
////        var status: Int32
////
////        var audio_stream_index: Int = 0
////        var video_stream_index: Int = 0
////
////        for i in 0..<inFormatContext!.pointee.nb_streams {
////
////            let stream = inFormatContext!.pointee.streams.advanced(by: Int(i)).pointee!.pointee
////
////            if (stream.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO) {
////
////                audio_stream_index = Int(i)
////
////                let c: UnsafeMutablePointer<AVCodec>? = avcodec_find_encoder(stream.codecpar.pointee.codec_id)
////                if let theCodec = c {
////
////                    let ostream: UnsafeMutablePointer<AVStream> = avformat_new_stream(outFormatContext, theCodec)
////                    avcodec_parameters_copy(ostream.pointee.codecpar, stream.codecpar)
////                    ostream.pointee.codecpar.pointee.codec_tag = 0
////                }
////
////            } else if (stream.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO) {
////
////                video_stream_index = Int(i)
////
////                let c: UnsafeMutablePointer<AVCodec>? = avcodec_find_encoder(stream.codecpar.pointee.codec_id)
////                if let theCodec = c {
////
////                    let ostream: UnsafeMutablePointer<AVStream> = avformat_new_stream(outFormatContext, theCodec)
////                    avcodec_parameters_copy(ostream.pointee.codecpar, stream.codecpar)
////                    ostream.pointee.codecpar.pointee.codec_tag = 0
////                }
////            }
////        }
////
////        av_dump_format(outFormatContext, 0, outFilePath, 1)
////
////        if (outFormatContext!.pointee.oformat.pointee.flags & AVFMT_NOFILE) == 0 {
////            avio_open(&outFormatContext!.pointee.pb, outFilePath, AVIO_FLAG_WRITE)
////        }
////
////        _ = avformat_init_output(outFormatContext, nil)
////        status = avformat_write_header(outFormatContext, nil)
////
////
////
////        let inAudioStream = inFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee
////        let inVideoStream = inFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee
////
////        var outAudioStream = outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee
////        var outVideoStream = outFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee
////
////        /* Free existing side data*/
////
////        for i in 0..<Int(outAudioStream.nb_side_data) {
////            av_free(outAudioStream.side_data[i].data)
////        }
////
////        av_freep(&(outAudioStream.side_data))
////        outAudioStream.nb_side_data = 0
////
////        /* Copy side data if present */
////
////        if let srcSideData = inAudioStream.side_data {
////
////            let rawPtr: UnsafeMutableRawPointer? = av_mallocz_array(Int(inAudioStream.nb_side_data),
////                                                                    MemoryLayout<AVPacketSideData>.size)
////
////            outAudioStream.side_data = UnsafeMutablePointer<AVPacketSideData>(OpaquePointer(rawPtr))
////            outAudioStream.nb_side_data = inAudioStream.nb_side_data
////
////            for i in 0..<Int(inAudioStream.nb_side_data) {
////
////                let srcSideDataForI: AVPacketSideData = srcSideData[i]
////
////                let data: UnsafeMutableRawPointer? = av_memdup(srcSideDataForI.data, Int(srcSideDataForI.size))
////                outAudioStream.side_data[i].type = srcSideDataForI.type
////                outAudioStream.side_data[i].size = srcSideDataForI.size
////                outAudioStream.side_data[i].data = UnsafeMutablePointer<UInt8>(OpaquePointer(data))
////            }
////        }
////
////        var pkt: UnsafeMutablePointer<AVPacket>? = av_packet_alloc()
////        av_init_packet(pkt)
////        pkt!.pointee.data = nil
////        pkt!.pointee.size = 0
////
////        while av_read_frame(inFormatContext, pkt) == 0 {
////            av_write_frame(outFormatContext, pkt)
////        }
////
////        av_packet_free(&pkt)
////
////        av_write_trailer(outFormatContext)
////
////        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
////
////        while let tag = av_dict_get(inVideoStream.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
////
////            let key = String(cString: tag.pointee.key)
////            let value = String(cString: tag.pointee.value)
////            av_dict_set(&outVideoStream.metadata, key, value, 0)
////
////            tagPtr = tag
////        }
////
////        avformat_close_input(&inFormatContext)
////        avformat_free_context(outFormatContext)
////        avformat_free_context(inFormatContext)
//    }
//
//    /// Indicates whether or not this object has already been destroyed.
//    private var destroyed: Bool = false
//
//    ///
//    /// Performs cleanup (deallocation of allocated memory space) when
//    /// this object is about to be deinitialized or is no longer needed.
//    ///
//    func destroy() {
//
//        // This check ensures that the deallocation happens
//        // only once. Otherwise, a fatal error will be
//        // thrown.
//        if destroyed {return}
//
//        // Destroy the constituent objects themselves.
//
//        //        audioCodec.destroy()
//        //        format.destroy()
//
//        destroyed = true
//    }
//
//    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
//    deinit {
//        destroy()
//    }
//}
//
