#include "ffmpeg.h"

int EOF_CODE = AVERROR_EOF;

int is_eof(int code) {
    return code == AVERROR_EOF;
}
