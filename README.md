# swift-ffmpeg

## What ?

A basic audio player project that demonstrates the fundamentals of decoding audio with ffmpeg for the purpose of real-time playback. The code is in Swift 
and the demo project will run on macOS, but could prove educational even to programmers of different languages/platforms.

### What else ?

You will find a bare bones AVAudioEngine setup here. < 100 lines of code with just a player that schedules buffers.

### In a nutshell, ... this
![High level component diagram](/basicFFmpegPlayer.png?raw=true)

## Who ?

Are you totally new to ffmpeg ? You just read/heard that there is this awesome library that plays everything and now you want to get started programming with it ? Great, you will like this.

Are you totally new to AVAudioEngine and you want to see a basic usage of it ? Great, you will find it here.

Are you totally new to audio programming in general ? Or want to develop your own player someday ? Welcome.

I am *not* trying to educate those of you who have been taming ffmpeg for years :)

## Why ?

It seems that there aren't too many similar **beginner-level** demo projects or tutorials related to ffmpeg out there. I myself searched for almost 3 whole years to finally learn enough to write this basic app. The few resources I found were overwhelming or contained a lot of concepts without a concrete implementation to play with.

I learn the most when I'm able to actually open, tweak, and run demo code in an IDE. I would have killed to have access to such a demo project 3 years ago when my audio programming journey began.

That said, I have shared links, below, to much bigger and more comprehensive resources which I myself learned from.

## How ?

Download the source and get it running in XCode. Open different types of music files, and see if/how it works.

Browse through the source code, which I have done my best to document. Tweak it to your heart's content, build it, run it, see (and hear) what happens!

Then, perhaps ... develop something much bigger and better yourself!

## Other helpful resources

Hopefully, this project will get you started, and once you get your feet wet, you will find these resources valuable.

* targodan's [ffmpeg decoding guide](https://steemit.com/programming/@targodan/decoding-audio-files-with-ffmpeg). Related code sample [here](https://gist.github.com/targodan/8cef8f2b682a30055aa7937060cd94b7). This tutorial is, hands down, the best one out there!

* [A detailed tutorial on the basics of ffmpeg](https://github.com/leandromoreira/ffmpeg-libav-tutorial) by leandromoreira.

* An [outdated but pretty detailed ffmpeg tutorial](https://dranger.com/ffmpeg/tutorial01.html) that others have recommended.

* rollmind's Swift/ffmpeg [demo app](https://github.com/rollmind/ffmpeg-swift-tutorial/tree/master/tutorial/tutorial) (somewhat outdated, but still helpful)

* Another [Swift player implementation](https://github.com/rollmind/SweetPlayer) by rollmind

* Sunlubo's [Swift wrapper for ffmpeg](https://github.com/sunlubo/SwiftFFmpeg)

* For a more full-fledged AVAudioEngine setup, I point you to my other (far bigger) project: [Aural Player](https://github.com/maculateConception/aural-player)

* A Swift ffmpeg [wrapper library](https://github.com/FFMS/ffms2) (that I'm not sure I understand but it should be mentioned).
