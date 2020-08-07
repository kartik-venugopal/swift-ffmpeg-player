#ifndef ffmpeg_h
#define ffmpeg_h

#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#import <libavutil/avutil.h>
#import <libavutil/error.h>
#import <libavutil/channel_layout.h>
#import <libavutil/dict.h>
#import <libavutil/opt.h>
#import <libavutil/mathematics.h>
#import <libavfilter/avfilter.h>
#import <libswresample/swresample.h>

long CH_LAYOUT_MONO;
long CH_LAYOUT_STEREO;
long CH_LAYOUT_2POINT1;
long CH_LAYOUT_2_1;
long CH_LAYOUT_SURROUND;
long CH_LAYOUT_3POINT1;
long CH_LAYOUT_4POINT0;
long CH_LAYOUT_4POINT1;
long CH_LAYOUT_2_2;
long CH_LAYOUT_QUAD;
long CH_LAYOUT_5POINT0;
long CH_LAYOUT_5POINT1;
long CH_LAYOUT_5POINT0_BACK;
long CH_LAYOUT_5POINT1_BACK;
long CH_LAYOUT_6POINT0;
long CH_LAYOUT_6POINT0_FRONT;
long CH_LAYOUT_HEXAGONAL;
long CH_LAYOUT_6POINT1;
long CH_LAYOUT_6POINT1_BACK;
long CH_LAYOUT_6POINT1_FRONT;
long CH_LAYOUT_7POINT0;
long CH_LAYOUT_7POINT0_FRONT;
long CH_LAYOUT_7POINT1;
long CH_LAYOUT_7POINT1_WIDE;
long CH_LAYOUT_7POINT1_WIDE_BACK;
long CH_LAYOUT_OCTAGONAL;
long CH_LAYOUT_HEXADECAGONAL;
long CH_LAYOUT_STEREO_DOWNMIX;

int ERROR_EOF;

#endif /* ffmpeg_h */
