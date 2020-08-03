# swift-ffmpeg

## What ?

A basic audio player project that demonstrates decoding audio with ffmpeg and playback of that audio with AVAudioEngine ... written in Swift.

### In a nutshell, ... this
![High level component diagram](/basicFFmpegPlayer.png?raw=true)

### What else ?

* Converting between different sample formats (resampling) with ffmpeg.
* Extracting metadata (artist/album, cover art, etc) with ffmpeg.
* Upmixing/downmmixing mono/surround audio to stereo, with AVAudioEngine.

## Why ?

There simply aren't enough **beginner-level** demo projects or tutorials related to ffmpeg out there. It should not have to take so much effort for someone to be able to get a quick n dirty ffmpeg-based player up and running in a couple of hours. So, here goes my attempt to make it easier.

That said, I have shared links, below, to much bigger and more comprehensive resources which I myself learned from.

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
