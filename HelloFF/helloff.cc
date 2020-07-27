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

void formattedDuration(int64_t duration)
{

    long secs = duration / 1000000;

    long hours = secs / 3600;
    secs -= hours * 3600;

    long minutes = secs / 60;
    secs -= minutes * 60;

    printf("Duration: %ld:%ld:%ld\n\n", hours, minutes, secs);
}

int main()
{
    av_register_all();

    AVFormatContext *formatCtx = avformat_alloc_context();
    if (!formatCtx)
    {
        printf("\nERROR could not allocate memory for Format Context");
        return -1;
    }

    if (avformat_open_input(&formatCtx, "/Volumes/MyData/Music/Aural-Test/D1.dsf", NULL, NULL) != 0)
    {

        printf("\n\n*** COULD NOT OPEN the damn file :( \n\n");
        return -1; // Couldn't open file
    }

    if (avformat_find_stream_info(formatCtx, NULL) < 0)
    {
        printf("ERROR could not get the stream info");
        return -1;
    }

    // printf("format %s, duration %lld us, bit_rate %lld\n\n", formatCtx->iformat->name, formatCtx->duration, formatCtx->bit_rate);
    formattedDuration(formatCtx->duration);

    for (int i = 0; i < formatCtx->nb_streams; i++)
    {
        AVCodecParameters *pLocalCodecParameters = formatCtx->streams[i]->codecpar;
        AVCodec *pLocalCodec = avcodec_find_decoder(pLocalCodecParameters->codec_id);

        if (pLocalCodecParameters->codec_type == AVMEDIA_TYPE_AUDIO)
        {
            printf("\nAudio Codec: %s, %d channels, sample rate %d\n\n", pLocalCodec->long_name, pLocalCodecParameters->channels, pLocalCodecParameters->sample_rate);
        }
        else if (pLocalCodecParameters->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            printf("Found Album Art of format: %s\n\n", pLocalCodec->long_name);

            AVCodecContext *pCodecContext = avcodec_alloc_context3(pLocalCodec);
            avcodec_parameters_to_context(pCodecContext, pLocalCodecParameters);
            avcodec_open2(pCodecContext, pLocalCodec, NULL);

            AVPacket *pPacket = av_packet_alloc();
            AVFrame *pFrame = av_frame_alloc();
            AVFrame *pFrameRGB = av_frame_alloc();

            av_read_frame(formatCtx, pPacket);

            FILE* image_file = fopen("/Volumes/MyData/Aural-Test/albumArt.jpg", "wb");
            int result = fwrite(pPacket->data, pPacket->size, 1, image_file);
            fclose(image_file);
        }
    }

    printf("Metadata ...\n\n");

    AVDictionaryEntry *tag = NULL;
    while ((tag = av_dict_get(formatCtx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX)))
        printf("%s=%s\n", tag->key, tag->value);

    avformat_close_input(&formatCtx);

    return 0;
}
