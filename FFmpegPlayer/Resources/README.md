# swift-ffmpeg-player

## What ?

A basic audio player that demonstrates the use of ffmpeg together with AVAudioEngine ... written in Swift.

![Screenshot](/CAndSwift/screenshot.png?raw=true)

### In a few more words, ...

![High level component diagram](/basicFFmpegPlayer.png?raw=true)

* Demuxing an audio file into streams - audio and image (cover art).
* Reading packets from an audio stream, and using a codec to decode the packets into PCM samples.
* Extracting metadata (artist/album, cover art, etc).
* Converting between different PCM sample formats (resampling).
* Constructing audio buffers with the PCM samples, and scheduling them for playback.
* Upmixing/downmixing from mono/surround audio to stereo.
* Seeking within a stream - by frame or byte position.
* Building a packet table when no duration or bit rate info is available, to compute duration and enable seeking.

## Why ?

To help anyone who wants to get started with ffmpeg / AVAudioEngine but is having a hard time finding (or making sense of) documentation, tutorials, or concrete implementations out there. Take this project as a starting point or quick start guide, if nothing else.

I myself am still learning audio programming and ffmpeg, so I am simply passing on some of what I have learned.

**Tip** - To get the most out of this project, I recommend that you follow [targodan's tutorial](https://steemit.com/programming/@targodan/decoding-audio-files-with-ffmpeg) as you play with my demo app.

## Other helpful resources

* targodan's [ffmpeg decoding guide](https://steemit.com/programming/@targodan/decoding-audio-files-with-ffmpeg). Related code sample [here](https://gist.github.com/targodan/8cef8f2b682a30055aa7937060cd94b7). This tutorial is, hands down, the best one out there!

* [A detailed tutorial on the basics of ffmpeg](https://github.com/leandromoreira/ffmpeg-libav-tutorial) by leandromoreira.

* An [outdated but pretty detailed ffmpeg tutorial](https://dranger.com/ffmpeg/tutorial01.html) that others have recommended.

* A [brief tutorial Ebook](https://riptutorial.com/ebook/ffmpeg) on ffmpeg decoding, in PDF format.

* rollmind's Swift/ffmpeg [demo app](https://github.com/rollmind/ffmpeg-swift-tutorial/tree/master/tutorial/tutorial) (somewhat outdated, but still helpful)

* Another [Swift player implementation](https://github.com/rollmind/SweetPlayer) by rollmind

* Sunlubo's [Swift wrapper for ffmpeg](https://github.com/sunlubo/SwiftFFmpeg)

* For a more full-fledged AVAudioEngine setup, I point you to my other (far bigger) project: [Aural Player](https://github.com/maculateConception/aural-player)

* A Swift ffmpeg [wrapper library](https://github.com/FFMS/ffms2) (that I'm not sure I understand but it should be mentioned).
