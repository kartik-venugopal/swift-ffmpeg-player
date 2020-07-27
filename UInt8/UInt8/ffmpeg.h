#ifndef ffmpeg_h
#define ffmpeg_h

#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#import <libavutil/avutil.h>
#import <libavutil/error.h>
#import <libavutil/dict.h>
#import <libavutil/opt.h>
#import <libavutil/mathematics.h>
#import <libavfilter/avfilter.h>
#import <libswresample/swresample.h>
#import <libswscale/swscale.h>

int EOF_CODE;

int is_eof(int code);

#endif /* ffmpeg_h */
