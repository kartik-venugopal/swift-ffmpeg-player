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
--enable-demuxers \
--disable-decoders \
--enable-decoder=8svx_exp,8svx_fib,aac,aac_fixed,aac_at,aac_latm,ac3,ac3_fixed,ac3_at,acelp.kelvin,adpcm_4xm,adpcm_adx,adpcm_afc,adpcm_agm,adpcm_aica,adpcm_argo,adpcm_ct,adpcm_dtk,adpcm_ea,adpcm_ea_maxis_xa,adpcm_ea_r1,adpcm_ea_r2,adpcm_ea_r3,adpcm_ea_xas,g722,g726,g726le,adpcm_ima_alp,adpcm_ima_amv,adpcm_ima_apc,adpcm_ima_apm,adpcm_ima_cunning,adpcm_ima_dat4,adpcm_ima_dk3,adpcm_ima_dk4,adpcm_ima_ea_eacs,adpcm_ima_ea_sead,adpcm_ima_iss,adpcm_ima_mtf,adpcm_ima_oki,adpcm_ima_qt,adpcm_ima_qt_at,adpcm_ima_rad,adpcm_ima_smjpeg,adpcm_ima_ssi,adpcm_ima_wav,adpcm_ima_ws,adpcm_ms,adpcm_mtaf,adpcm_psx,adpcm_sbpro_2,adpcm_sbpro_3,adpcm_sbpro_4,adpcm_swf,adpcm_thp,adpcm_thp_le,adpcm_vima,adpcm_xa,adpcm_yamaha,adpcm_zork,alac,alac_at,amrnb,amr_nb_at,libopencore_amrnb,amrwb,libopencore_amrwb,ape,aptx,aptx_hd,atrac1,atrac3,atrac3al,atrac3plus,atrac3plusal,atrac9,on2avc,binkaudio_dct,binkaudio_rdft,bmv_audio,comfortnoise,cook,derf_dpcm,dolby_e,dsd_lsbf,dsd_lsbf_planar,dsd_msbf,dsd_msbf_planar,dsicinaudio,dss_sp,dst,dca,dvaudio,eac3,eac3_at,evrc,flac,g723_1,g729,gremlin_dpcm,gsm,gsm_ms,gsm_ms_at,hca,hcom,iac,ilbc,ilbc_at,imc,interplay_dpcm,interplayacm,mace3,mace6,metasound,mlp,mp1,mp1float,mp1_at,mp2,mp2float,mp2_at,mp3float,mp3,mp3_at,mp3adufloat,mp3adu,mp3on4float,mp3on4,als,mpc7,mpc8,nellymoser,opus,libopus,paf_audio,pcm_alaw,pcm_alaw_at,pcm_bluray,pcm_dvd,pcm_f16le,pcm_f24le,pcm_f32be,pcm_f32le,pcm_f64be,pcm_f64le,pcm_lxf,pcm_mulaw,pcm_mulaw_at,pcm_s16be,pcm_s16be_planar,pcm_s16le,pcm_s16le_planar,pcm_s24be,pcm_s24daud,pcm_s24le,pcm_s24le_planar,pcm_s32be,pcm_s32le,pcm_s32le_planar,pcm_s64be,pcm_s64le,pcm_s8,pcm_s8_planar,pcm_u16be,pcm_u16le,pcm_u24be,pcm_u24le,pcm_u32be,pcm_u32le,pcm_u8,pcm_vidc,qcelp,qdm2,qdm2_at,qdmc,qdmc_at,real_144,real_288,ralf,roq_dpcm,s302m,sbc,sdx2_dpcm,shorten,sipr,siren,smackaud,sol_dpcm,sonic,libspeex,tak,truehd,truespeech,tta,twinvq,vmdaudio,vorbis,libvorbis,wavesynth,wavpack,ws_snd1,wmalossless,wmapro,wmav1,wmav2,wmavoice,xan_dpcm,xma1,xma2 \
--disable-parsers \
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
