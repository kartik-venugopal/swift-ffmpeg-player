//
//  ffmpeg.c
//  Aural
//
//  Copyright © 2021 Kartik Venugopal. All rights reserved.
//
//  This software is licensed under the MIT software license.
//  See the file "LICENSE" in the project root directory for license terms.
//
#include "ffmpeg.h"

/**
 *  This file exposes constants and macros defined in ffmpeg with "#define" that are not otherwise available
 *   to Swift code.
 */

/**
 * The error code corresponding to end of file (EOF). Defined in <libavutil/error.h>.
 */
int ERROR_EOF = AVERROR_EOF;
