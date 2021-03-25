import Foundation

///
/// Encapsulates a context for reading audio data / metadata from a single audio file using ffmpeg.
///
/// Instantiates, provides, and manages the life cycles of several member objects through which several ffmpeg functions can be executed.
///
class MetadataEditingContext {

    ///
    /// The audio file to be read / decoded by this context.
    ///
    let file: URL

    var inFormatContext: UnsafeMutablePointer<AVFormatContext>?

    var outFormatContext: UnsafeMutablePointer<AVFormatContext>?

    let outFilePath: String

    var title: String? {

        didSet {
            av_dict_set(&outFormatContext!.pointee.metadata, "TIT2", title, 0)
        }
    }

    var artist: String? {

        didSet {
            av_dict_set(&outFormatContext!.pointee.metadata, "TPE1", artist, 0)
        }
    }

    var album: String? {

        didSet {
            av_dict_set(&outFormatContext!.pointee.metadata, "TALB", album, 0)
        }
    }

    var genre: String? {

        didSet {
            av_dict_set(&outFormatContext!.pointee.metadata, "TCON", genre, 0)
        }
    }

    ///
    /// Attempts to construct an AudioFileContext instance for the given file.
    ///
    /// - Parameter file: The audio file to be read / decoded by this context.
    ///
    /// Fails (returns nil) if:
    ///
    /// - An error occurs while opening the file or reading (demuxing) its streams.
    /// - No audio stream is found in the file.
    /// - No suitable codec is found for the audio stream.
    ///
    /// # Note #
    ///
    /// If this initializer succeeds (does not return nil), it indicates that the file being read:
    ///
    /// 1. Is a valid media file.
    /// 2. Has at least one audio stream.
    /// 3. Is able to decode that audio stream.
    ///
    init?(forFile file: URL) {

        self.file = file
        self.outFilePath = "/Users/kven/Music/TagEdit/tagEditOut-\(Int.random(in: 1000..<1000000)).mp3"

        inFormatContext = avformat_alloc_context()

        if avformat_open_input(&inFormatContext, file.path, nil, nil) < 0 {
            print("Open input failed")
        }

        if avformat_find_stream_info(inFormatContext, nil) < 0 {
            print("find stream info failed")
        }
        
        let ofmt: UnsafeMutablePointer<AVOutputFormat>? = av_guess_format("mp3", outFilePath, nil)
        let status = avformat_alloc_output_context2(&outFormatContext, ofmt, "mp3", outFilePath)

        if (status < 0) {
            print("could not allocate output format")
            return nil
        }

        var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?

        while let tag = av_dict_get(inFormatContext!.pointee.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {

            let key = String(cString: tag.pointee.key)
            let value = String(cString: tag.pointee.value)
            av_dict_set(&outFormatContext!.pointee.metadata, key, value, 0)

            tagPtr = tag
        }
        
        self.title = "Muthu"
        self.artist = "Sami"
        self.album = "Papa"
        self.genre = "Pandi"
        
        save()
    }

    func save() {

            var status: Int32

            var audio_stream_index: Int = 0
            var video_stream_index: Int = 0

            for i in 0..<inFormatContext!.pointee.nb_streams {

                let stream = inFormatContext!.pointee.streams.advanced(by: Int(i)).pointee!.pointee

                if (stream.codecpar.pointee.codec_type == AVMEDIA_TYPE_AUDIO) {

                    audio_stream_index = Int(i)

                    let c: UnsafeMutablePointer<AVCodec>? = avcodec_find_encoder(stream.codecpar.pointee.codec_id)
                    if let theCodec = c {

                        let ostream: UnsafeMutablePointer<AVStream> = avformat_new_stream(outFormatContext, theCodec)
                        avcodec_parameters_copy(ostream.pointee.codecpar, stream.codecpar)
                        ostream.pointee.codecpar.pointee.codec_tag = 0
                    }

                } else if (stream.codecpar.pointee.codec_type == AVMEDIA_TYPE_VIDEO) {

                    video_stream_index = Int(i)

                    let c: UnsafeMutablePointer<AVCodec>? = avcodec_find_encoder(stream.codecpar.pointee.codec_id)
                    if let theCodec = c {

                        let ostream: UnsafeMutablePointer<AVStream> = avformat_new_stream(outFormatContext, theCodec)
                        avcodec_parameters_copy(ostream.pointee.codecpar, stream.codecpar)
                        ostream.pointee.codecpar.pointee.codec_tag = 0
                    }
                }
            }

            if (outFormatContext!.pointee.oformat.pointee.flags & AVFMT_NOFILE) == 0 {
                avio_open(&outFormatContext!.pointee.pb, outFilePath, AVIO_FLAG_WRITE)
            }

            _ = avformat_init_output(outFormatContext, nil)

            let inAudioStream = inFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee
            let inVideoStream = inFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee

            var outAudioStream = outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee
            var outVideoStream = outFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee
        
        av_dict_copy(&outFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee.metadata, inVideoStream.metadata, 0)
        
        av_dict_set(&outFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee.metadata, "muthu", "Sami", 0)
        
        
//        if  let sd = inAudioStream.side_data {
//
//            print("Side Data NB: \(inAudioStream.nb_side_data)")
//
//            let data = sd.pointee
//            print("SD: \(data.type) \(data.size) \(data.data)")
//
////            for index in 0..<Int(inAudioStream.nb_side_data) {
////
////                let sdi = sd[index]
////                print("\(index): \(sdi.type) \(sdi.size) \(sdi.data)")
////            }
//        }

            /* Free existing side data*/

            for i in 0..<Int(outAudioStream.nb_side_data) {
                av_free(outAudioStream.side_data[i].data)
            }

            av_freep(&(outAudioStream.side_data))
            outAudioStream.nb_side_data = 0

            /* Copy side data if present */

            if let srcSideData = inAudioStream.side_data {
                
                let rawPtr: UnsafeMutableRawPointer? = av_mallocz_array(Int(inAudioStream.nb_side_data),
                                                                            MemoryLayout<AVPacketSideData>.size)
                                
                outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.side_data = UnsafeMutablePointer<AVPacketSideData>(OpaquePointer(rawPtr))
                
                outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.nb_side_data = inAudioStream.nb_side_data

                for i in 0..<Int(inAudioStream.nb_side_data) {

                    let srcSideDataForI: AVPacketSideData = srcSideData[i]

                    let data: UnsafeMutableRawPointer? = av_memdup(srcSideDataForI.data, Int(srcSideDataForI.size))
                    outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.side_data[i].type = srcSideDataForI.type
                    outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.side_data[i].size = srcSideDataForI.size
                    outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.side_data[i].data = UnsafeMutablePointer<UInt8>(OpaquePointer(data))

//                    _ = av_stream_add_side_data(outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!, srcSideDataForI.type, outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.side_data[i].data, Int(srcSideDataForI.size))
                }
            }
        
//        av_format_inject_global_side_data(outFormatContext)
        
        status = avformat_write_header(outFormatContext, nil)

            var pkt: UnsafeMutablePointer<AVPacket>? = av_packet_alloc()
            av_init_packet(pkt)
            pkt!.pointee.data = nil
            pkt!.pointee.size = 0

            while av_read_frame(inFormatContext, pkt) == 0 {
                av_write_frame(outFormatContext, pkt)
            }

            av_packet_free(&pkt)
        
            av_write_trailer(outFormatContext)

//            var tagPtr: UnsafeMutablePointer<AVDictionaryEntry>?
//
//            while let tag = av_dict_get(inVideoStream.metadata, "", tagPtr, AV_DICT_IGNORE_SUFFIX) {
//
//                let key = String(cString: tag.pointee.key)
//                let value = String(cString: tag.pointee.value)
//                av_dict_set(&outFormatContext!.pointee.streams.advanced(by: Int(video_stream_index)).pointee!.pointee.metadata, key, value, 0)
//
//                tagPtr = tag
//            }
        
        if  let sd = outFormatContext?.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.side_data {
            
            print("OUTSide Data NB: \(outFormatContext!.pointee.streams.advanced(by: Int(audio_stream_index)).pointee!.pointee.nb_side_data)")
            
            let data = sd.pointee
            print("OUT-SD: \(data.type) \(data.size) \(data.data)")
        }
        
            av_dump_format(outFormatContext, 0, outFilePath, 1)
        
            avformat_close_input(&inFormatContext)
            avformat_free_context(outFormatContext)
            avformat_free_context(inFormatContext)
    }

    /// Indicates whether or not this object has already been destroyed.
    private var destroyed: Bool = false

    ///
    /// Performs cleanup (deallocation of allocated memory space) when
    /// this object is about to be deinitialized or is no longer needed.
    ///
    func destroy() {

        // This check ensures that the deallocation happens
        // only once. Otherwise, a fatal error will be
        // thrown.
        if destroyed {return}

        // Destroy the constituent objects themselves.

//        audioCodec.destroy()
//        format.destroy()

        destroyed = true
    }

    /// When this object is deinitialized, make sure that its allocated memory space is deallocated.
    deinit {
        destroy()
    }
}

