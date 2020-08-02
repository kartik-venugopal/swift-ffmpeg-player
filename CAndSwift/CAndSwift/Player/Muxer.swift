import Foundation

class Muxer {
    
    // outputFileFormat: File extension of the desired output format. eg. "mka" or "m4a".
    func mux(rawFile: AudioFileContext, outputFileFormat: String) {
        
        var ofmt: UnsafeMutablePointer<AVOutputFormat>?
        var ifmt_ctx: UnsafeMutablePointer<AVFormatContext>? = rawFile.format.pointer
        var ofmt_ctx: UnsafeMutablePointer<AVFormatContext>? = nil
        var pkt: AVPacket
        var out_filename: String = "/Volumes/MyData/Music/Aural-Test/0muxed.mka"
        var ret: Int32
        var i: Int
        var stream_index: Int = 0
        var stream_mapping: UnsafeMutablePointer<Int>? = nil
        var stream_mapping_size: Int = 0
        
        avformat_alloc_output_context2(&ofmt_ctx, nil, nil, out_filename)
        
        if ofmt_ctx == nil {
        
            print("Could not create output context\n");
            
            cleanUp(inFmtCtx: ifmt_ctx, outFmtCtx: ofmt_ctx, ofmt: ofmt)
            return
        }

        var out_stream: UnsafeMutablePointer<AVStream>?
        var in_stream: UnsafeMutablePointer<AVStream>? = rawFile.audioStream.pointer
        var in_codecpar: UnsafeMutablePointer<AVCodecParameters> = rawFile.audioCodec.paramsPointer
        
        out_stream = avformat_new_stream(ofmt_ctx, nil)
        
        if out_stream == nil {
            
            print("Failed allocating output stream\n");
            
            cleanUp(inFmtCtx: ifmt_ctx, outFmtCtx: ofmt_ctx, ofmt: ofmt)
            return
        }
        
        ret = avcodec_parameters_copy(out_stream!.pointee.codecpar, in_codecpar)
        
        if ret.isNegative {
            
            print("Failed to copy codec parameters\n");
            
            cleanUp(inFmtCtx: ifmt_ctx, outFmtCtx: ofmt_ctx, ofmt: ofmt)
            return
        }
        
        out_stream!.pointee.codecpar.pointee.codec_tag = 0;
        
//        AVStream *in_stream = ifmt_ctx->streams[i];
//        AVCodecParameters *in_codecpar = in_stream->codecpar;
//
//        if (in_codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
//            in_codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
//            in_codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
//            stream_mapping[i] = -1;
//            continue;
//        }
//
//        stream_mapping[i] = stream_index++;
//
//        out_stream = avformat_new_stream(ofmt_ctx, NULL);
//        if (!out_stream) {
//            fprintf(stderr, "Failed allocating output stream\n");
//            ret = AVERROR_UNKNOWN;
//            goto end;
//        }
//
//        ret = avcodec_parameters_copy(out_stream->codecpar, in_codecpar);
//        if (ret < 0) {
//            fprintf(stderr, "Failed to copy codec parameters\n");
//            goto end;
//        }
//        out_stream->codecpar->codec_tag = 0;
        
//        if (!stream_mapping) {
//            ret = AVERROR(ENOMEM);
//            goto end;
//        }
     
//        if ret.isNegative && ret != EOF_CODE {
//            print("Error occurred: %s\n", ret.errorDescription);
//        }
    }
    
    private func cleanUp(inFmtCtx: UnsafeMutablePointer<AVFormatContext>?, outFmtCtx: UnsafeMutablePointer<AVFormatContext>?, ofmt: UnsafeMutablePointer<AVOutputFormat>?) {
        
        var ifmt_ctx: UnsafeMutablePointer<AVFormatContext>? = inFmtCtx
        let ofmt_ctx: UnsafeMutablePointer<AVFormatContext>? = outFmtCtx
        
        avformat_close_input(&ifmt_ctx)

        /* close output */
        if (ofmt_ctx != nil && (ofmt!.pointee.flags & AVFMT_NOFILE == 0)) {
            
            avio_closep(&ofmt_ctx!.pointee.pb)
            avformat_free_context(ofmt_ctx)
        }


    }
}
