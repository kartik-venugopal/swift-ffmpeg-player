extern "C"
{
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
}

#ifndef __cplusplus
    typedef uint8_t bool;
    #define true 1
    #define false 0
#endif

#ifdef __cplusplus
    #define REINTERPRET_CAST(type, variable) reinterpret_cast<type>(variable)
    #define STATIC_CAST(type, variable) static_cast<type>(variable)
#else
    #define C_CAST(type, variable) ((type)variable)
    #define REINTERPRET_CAST(type, variable) C_CAST(type, variable)
    #define STATIC_CAST(type, variable) C_CAST(type, variable)
#endif

#define RAW_OUT_ON_PLANAR true

FILE* outFile;

int ctr = 0;

/**
 * Print an error string describing the errorCode to stderr.
 */
int printError(const char* prefix, int errorCode) {
    
    if(errorCode == 0) {
        return 0;
    } else {
        const size_t bufsize = 64;
        char buf[bufsize];

        if(av_strerror(errorCode, buf, bufsize) != 0) {
            strcpy(buf, "UNKNOWN_ERROR");
        }
        fprintf(stderr, "%s (%d: %s)\n", prefix, errorCode, buf);

        return errorCode;
    }
}

void formattedDuration(int64_t duration) {

    long secs = duration / 1000000;

    long hours = secs / 3600;
    secs -= hours * 3600;

    long minutes = secs / 60;
    secs -= minutes * 60;

    printf("Duration: %ld:%ld:%ld\n\n", hours, minutes, secs);
}

/**
 * Find the first audio stream and returns its index. If there is no audio stream returns -1.
 */
int findAudioStream(const AVFormatContext* formatCtx) {

    int audioStreamIndex = -1;

    for(size_t i = 0; i < formatCtx->nb_streams; ++i) {
        // Use the first audio stream we can find.
        // NOTE: There may be more than one, depending on the file.
        if(formatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioStreamIndex = i;
            break;
        }
    }
    return audioStreamIndex;
}

/**
 * Extract a single sample and convert to float.
 */
float getSample(const AVCodecContext* codecCtx, uint8_t* buffer, int sampleIndex) {

    int64_t val = 0;
    float fltSample = 0;
    int sampleSize = av_get_bytes_per_sample(codecCtx->sample_fmt);
    
    switch(sampleSize) {

        case 1:
            // 8bit samples are always unsigned
            val = REINTERPRET_CAST(uint8_t*, buffer)[sampleIndex];
            // make signed
            val -= 127;
            break;

        case 2:
            val = REINTERPRET_CAST(int16_t*, buffer)[sampleIndex];
            break;

        case 4:
            val = REINTERPRET_CAST(int32_t*, buffer)[sampleIndex];
            break;

        case 8:
            val = REINTERPRET_CAST(int64_t*, buffer)[sampleIndex];
            break;

        default:
            fprintf(stderr, "Invalid sample size %d.\n", sampleSize);
            return 0;
    }

    // Check which data type is in the sample.
    switch(codecCtx->sample_fmt) {

        case AV_SAMPLE_FMT_U8:
        case AV_SAMPLE_FMT_S16:
        case AV_SAMPLE_FMT_S32:
        case AV_SAMPLE_FMT_U8P:
        case AV_SAMPLE_FMT_S16P:
        case AV_SAMPLE_FMT_S32P:

            // integer => Scale to [-1, 1] and convert to float.
            fltSample = val / STATIC_CAST(float, ((1 << (sampleSize*8 - 1)) - 1));
            break;

        case AV_SAMPLE_FMT_FLT:
        case AV_SAMPLE_FMT_FLTP:

            // float => reinterpret
            fltSample = *REINTERPRET_CAST(float*, &val);
            break;

        case AV_SAMPLE_FMT_DBL:
        case AV_SAMPLE_FMT_DBLP:
            // double => reinterpret and then static cast down
            fltSample = STATIC_CAST(float, *REINTERPRET_CAST(double*, &val));
            break;

        default:
            fprintf(stderr, "Invalid sample format %s.\n", av_get_sample_fmt_name(codecCtx->sample_fmt));
            return 0;
    }

    return fltSample;
}

/**
 * Write the frame to an output file.
 */
void handleFrame(const AVCodecContext* codecCtx, const AVFrame* frame) {

    // PLANAR SAMPLE FORMAT
    if(av_sample_fmt_is_planar(codecCtx->sample_fmt) == 1) {

        // This means that the data of each channel is in its own buffer.
        // => frame->extended_data[i] contains data for the i-th channel.
        for(int s = 0; s < frame->nb_samples; ++s) {

            for(int c = 0; c < codecCtx->channels; ++c) {

                float sample = getSample(codecCtx, frame->extended_data[c], s);
                fwrite(&sample, sizeof(float), 1, outFile);
                ctr++;

                if (ctr > 44100 && ctr < 44200) {
                    printf("%d: %f\n", ctr, sample);
                }
            }
        }

    } else {

        // PACKED (NON-PLANAR) SAMPLE FORMAT

        // This means that the data of each channel is in the same buffer.
        // => frame->extended_data[0] contains data of all channels.
        // if(RAW_OUT_ON_PLANAR) {

        //     fwrite(frame->extended_data[0], 1, frame->linesize[0], outFile);

        // } else {
            for(int s = 0; s < frame->nb_samples; ++s) {

                for(int c = 0; c < codecCtx->channels; ++c) {

                    float sample = getSample(codecCtx, frame->extended_data[0], s*codecCtx->channels+c);
                    fwrite(&sample, sizeof(float), 1, outFile);
                    ctr++;

                    if (ctr > 44100 && ctr < 44200) {
                        printf("%d: %f\n", ctr, sample);
                    }
                }
            }
        // }
    }
}

/**
 * Receive as many frames as available and handle them.
 */
int receiveAndHandle(AVCodecContext* codecCtx, AVFrame* frame) {

    int err = 0;
    // Read the packets from the decoder.
    // NOTE: Each packet may generate more than one frame, depending on the codec.
    while((err = avcodec_receive_frame(codecCtx, frame)) == 0) {
        // Let's handle the frame in a function.
        handleFrame(codecCtx, frame);
        // Free any buffers and reset the fields to default values.
        av_frame_unref(frame);
    }
    return err;
}

/*
 * Drain any buffered frames.
 */
void drainDecoder(AVCodecContext* codecCtx, AVFrame* frame) {

    int err = 0;

    // Some codecs may buffer frames. Sending NULL activates drain-mode.
    if((err = avcodec_send_packet(codecCtx, NULL)) == 0) {

        // Read the remaining packets from the decoder.
        err = receiveAndHandle(codecCtx, frame);

        if(err != AVERROR(EAGAIN) && err != AVERROR_EOF) {

            // Neither EAGAIN nor EOF => Something went wrong.
            printError("Receive error.", err);
        }

    } else {

        // Something went wrong.
        printError("Send error.", err);
    }
}

/*
 * Print information about the input file and the used codec.
 */
void printStreamInformation(const AVCodec* codec, const AVCodecContext* codecCtx, int audioStreamIndex) {

    fprintf(stderr, "Codec: %s\n", codec->long_name);

    if(codec->sample_fmts != NULL) {

        fprintf(stderr, "Supported sample formats: ");

        for(int i = 0; codec->sample_fmts[i] != -1; ++i) {
            fprintf(stderr, "%s", av_get_sample_fmt_name(codec->sample_fmts[i]));
            if(codec->sample_fmts[i+1] != -1) {
                fprintf(stderr, ", ");
            }
        }
        fprintf(stderr, "\n");
    }

    fprintf(stderr, "---------\n");
    fprintf(stderr, "Stream:        %7d\n", audioStreamIndex);
    fprintf(stderr, "Sample Format: %7s\n", av_get_sample_fmt_name(codecCtx->sample_fmt));
    fprintf(stderr, "Sample Rate:   %7d\n", codecCtx->sample_rate);
    fprintf(stderr, "Sample Size:   %7d\n", av_get_bytes_per_sample(codecCtx->sample_fmt));
    fprintf(stderr, "Channels:      %7d\n", codecCtx->channels);
    fprintf(stderr, "Float Output:  %7s\n\n", !RAW_OUT_ON_PLANAR || av_sample_fmt_is_planar(codecCtx->sample_fmt) ? "yes" : "no");
}

int main(int argc, char *argv[])
{

    printError("It is:", -35);
    char* filename = argv[1];

    // Open the outfile called "<infile>.raw".
    char* outFilename = REINTERPRET_CAST(char*, malloc(strlen(filename)+5));
    strcpy(outFilename, filename);
    strcpy(outFilename+strlen(filename), ".raw");

    outFile = fopen(outFilename, "w+");
    if(outFile == NULL) {
        fprintf(stderr, "Unable to open output file \"%s\".\n", outFilename);
    }
    free(outFilename);

    av_register_all();

    printf("\nDecoding ... !!! :D\n\n");

    AVFormatContext *formatCtx = avformat_alloc_context();
    if (!formatCtx)
    {
        printf("\nERROR could not allocate memory for Format Context");
        return -1;
    }

    if (avformat_open_input(&formatCtx, filename, NULL, NULL) != 0)
    {
        printf("\n\n*** COULD NOT OPEN the damn file :( \n\n");
        return -1; // Couldn't open file
    }

    if (avformat_find_stream_info(formatCtx, NULL) < 0)
    {
        printf("ERROR could not get the stream info");
        return -1;
    }

    int audioStreamIndex = findAudioStream(formatCtx);
    if(audioStreamIndex == -1) {
        // No audio stream was found.
        fprintf(stderr, "None of the available %d streams are audio streams.\n", formatCtx->nb_streams);
        avformat_close_input(&formatCtx);
        return -1;
    }

    // Find the correct decoder for the codec.
    AVCodec* codec = avcodec_find_decoder(formatCtx->streams[audioStreamIndex]->codecpar->codec_id);
    if (codec == NULL) {
        // Decoder not found.
        fprintf(stderr, "Decoder not found. The codec is not supported.\n");
        avformat_close_input(&formatCtx);
        return -1;
    }

    // Initialize codec context for the decoder.
    AVCodecContext* codecCtx = avcodec_alloc_context3(codec);
    if (codecCtx == NULL) {
        // Something went wrong. Cleaning up...
        avformat_close_input(&formatCtx);
        fprintf(stderr, "Could not allocate a decoding context.\n");
        return -1;
    }

    int err = 0;
    // Fill the codecCtx with the parameters of the codec used in the read file.
    if ((err = avcodec_parameters_to_context(codecCtx, formatCtx->streams[audioStreamIndex]->codecpar)) != 0) {
        // Something went wrong. Cleaning up...
        avcodec_close(codecCtx);
        avcodec_free_context(&codecCtx);
        avformat_close_input(&formatCtx);
        return printError("Error setting codec context parameters.", err);
    }

    // Explicitly request non planar data.
    codecCtx->request_sample_fmt = av_get_alt_sample_fmt(codecCtx->sample_fmt, 0);

    // Initialize the decoder.
    if ((err = avcodec_open2(codecCtx, codec, NULL)) != 0) {
        avcodec_close(codecCtx);
        avcodec_free_context(&codecCtx);
        avformat_close_input(&formatCtx);
        return -1;
    }

    AV_TIME_BASE

    // Print some intersting file information.
    printStreamInformation(codec, codecCtx, audioStreamIndex);

    AVFrame* frame = NULL;
    if ((frame = av_frame_alloc()) == NULL) {
        avcodec_close(codecCtx);
        avcodec_free_context(&codecCtx);
        avformat_close_input(&formatCtx);
        return -1;
    }

    // Prepare the packet.
    AVPacket packet;
    // Set default values.
    av_init_packet(&packet);    

    while ((err = av_read_frame(formatCtx, &packet)) != AVERROR_EOF) {

        if(err != 0) {
            // Something went wrong.
            printError("Read error.", err);
            break; // Don't return, so we can clean up nicely.
        }

        // Does the packet belong to the correct stream?
        if(packet.stream_index != audioStreamIndex) {
            // Free the buffers used by the frame and reset all fields.
            av_packet_unref(&packet);
            continue;
        }

        // We have a valid packet => send it to the decoder.
        if((err = avcodec_send_packet(codecCtx, &packet)) == 0) {
            // The packet was sent successfully. We don't need it anymore.
            // => Free the buffers used by the frame and reset all fields.
            av_packet_unref(&packet);

        } else {
            // Something went wrong.
            // EAGAIN is technically no error here but if it occurs we would need to buffer
            // the packet and send it again after receiving more frames. Thus we handle it as an error here.
            printError("Send error.", err);
            break; // Don't return, so we can clean up nicely.
        }

        // Receive and handle frames.
        // EAGAIN means we need to send before receiving again. So thats not an error.
        if((err = receiveAndHandle(codecCtx, frame)) != AVERROR(EAGAIN)) {
            // Not EAGAIN => Something went wrong.
            printError("Receive error.", err);
            break; // Don't return, so we can clean up nicely.
        }
    }

    // Drain the decoder.
    drainDecoder(codecCtx, frame);

    // Free all data used by the frame.
    av_frame_free(&frame);

    // Close the context and free all data associated to it, but not the context itself.
    avcodec_close(codecCtx);

    // Free the context itself.
    avcodec_free_context(&codecCtx);

    // We are done here. Close the input.
    avformat_close_input(&formatCtx);

    // Close the outfile.
    fclose(outFile);

    return 0;
}
