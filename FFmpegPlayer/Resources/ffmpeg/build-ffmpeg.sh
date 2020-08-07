#!/bin/sh

# Pre-requisites (need to be installed on this system to build FFmpeg) :
#
# nasm - assembler for x86 (Run "brew install nasm" ... requires Homebrew)
# clang - C compiler (Run "xcode-select --install")

# Binaries will be placed one level above the source folder (i.e. in the same location as this script)
export binDir=".."

# The name of the FFmpeg source code archive (which will be expanded)
export sourceArchiveName="ffmpeg-sourceCode.bz2"

# The name of the FFmpeg source directory (once the archive has been uncompressed)
export sourceDirectoryName="ffmpeg-4.3.1"

# Extract source code from archive
echo "\nExtracting FFmpeg sources from archive ..."
tar xjf $sourceArchiveName
echo "Done extracting FFmpeg sources from archive.\n"

# CD to the source directory and configure FFmpeg
cd $sourceDirectoryName
pwd
echo "Configuring FFmpeg ..."

#--pkg-config-flags="--shared"
#--extra-ldexeflags="-Bshared -mmacosx-version-min=10.12"
#--extra-ldflags="-Bshared -mmacosx-version-min=10.12"
#--extra-cflags="-Bshared -mmacosx-version-min=10.12"

./configure \
--cc=/usr/bin/clang \
--extra-ldexeflags="-mmacosx-version-min=10.12" \
--extra-ldflags="-mmacosx-version-min=10.12" \
--extra-cflags="-mmacosx-version-min=10.12" \
--bindir="$binDir" \
--enable-gpl \
--enable-version3 \
--enable-shared \
--disable-static \
--enable-runtime-cpudetect \
--enable-pthreads \
--disable-doc \
--disable-txtpages \
--disable-htmlpages \
--disable-manpages \
--disable-podpages \
--disable-debug \
--disable-swscale \
--disable-avdevice \
--disable-ffplay \
--disable-ffmpeg \
--disable-ffprobe \
--disable-network \
--disable-postproc \
--disable-avfoundation \
--disable-appkit \
--disable-audiotoolbox \
--disable-coreimage \
--disable-protocols \
--disable-zlib \
--disable-bzlib \
--disable-lzma \
--enable-protocol=file \
--disable-indevs \
--disable-outdevs \
--disable-videotoolbox \
--disable-securetransport \
--disable-bsfs \
--disable-filters \
--disable-demuxers \
--enable-demuxer=aac,ape,asf,dsf,flac,mp3,mpc,mpc8,wv,dts,dtshd \
--enable-demuxer=ogg,matroska \
--enable-demuxer=mjpeg,mjpeg_2000,mpjpeg \
--disable-decoders \
--enable-decoder=aac,ape,flac,mp1,mp1_at,mp1float,mp2,mp2_at,mp2float,mpc7,mpc8,dsd_lsbf,dsd_lsbf_planar,dsd_msbf,dsd_msbf_planar,opus,vorbis,wavpack,wmav1,wmav2,wmalossless,wmapro,wmavoice,dca \
--enable-decoder=bmp,png,jpeg2000,jpegls,mjpeg,mjpegb \
--disable-parsers \
--enable-parser=aac,flac,mpegaudio,opus,vorbis,dca,ac3 \
--enable-parser=bmp,mjpeg,png \
--disable-encoders

echo "Done configuring FFmpeg.\n"

# Build FFmpeg
echo "Building FFmpeg ..."
make && make install
echo "Done building FFmpeg."

cd ..
mkdir dylibs
cp $sourceDirectoryName/libavcodec/libavcodec.58.dylib dylibs
cp $sourceDirectoryName/libavformat/libavformat.58.dylib dylibs
cp $sourceDirectoryName/libavutil/libavutil.56.dylib dylibs
cp $sourceDirectoryName/libswresample/libswresample.3.dylib dylibs

cd dylibs

install_name_tool -id @loader_path/../Frameworks/libavcodec.58.dylib libavcodec.58.dylib
install_name_tool -change /usr/local/lib/libswresample.3.dylib @loader_path/../Frameworks/libswresample.3.dylib libavcodec.58.dylib
install_name_tool -change /usr/local/lib/libavutil.56.dylib @loader_path/../Frameworks/libavutil.56.dylib libavcodec.58.dylib

install_name_tool -id @loader_path/../Frameworks/libavformat.58.dylib libavformat.58.dylib
install_name_tool -change /usr/local/lib/libavcodec.58.dylib @loader_path/../Frameworks/libavcodec.58.dylib libavformat.58.dylib
install_name_tool -change /usr/local/lib/libswresample.3.dylib @loader_path/../Frameworks/libswresample.3.dylib libavformat.58.dylib
install_name_tool -change /usr/local/lib/libavutil.56.dylib @loader_path/../Frameworks/libavutil.56.dylib libavformat.58.dylib

install_name_tool -id @loader_path/../Frameworks/libavutil.56.dylib libavutil.56.dylib

install_name_tool -id @loader_path/../Frameworks/libswresample.3.dylib libswresample.3.dylib
install_name_tool -change /usr/local/lib/libavutil.56.dylib @loader_path/../Frameworks/libavutil.56.dylib libswresample.3.dylib

# Delete source directory
#rm -rf ../$sourceDirectoryName
