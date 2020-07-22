# swift-ffmpeg

## What ?

A basic audio player project that demonstrates the fundamentals of decoding audio with ffmpeg for the purpose of real-time playback. The code is in Swift 
and the demo project will run on macOS, but could prove educational even to programmers of different languages/platforms.

### What else ?

* You will find a bare bones AVAudioEngine setup here. < 100 lines of code with just a player that schedules buffers.
* In addition to real-time audio playback, you will see how to extract metadata (artist/album, cover art, etc) with ffmpeg.

### In a nutshell, ... this
![High level component diagram](/basicFFmpegPlayer.png?raw=true)

## Who ?

Are you totally new to ffmpeg ? You just read/heard that there is this awesome library that plays everything and now you want to get started programming with it ? Great, you will like this.

Are you totally new to AVAudioEngine and you want to see a basic usage of it ? Great, you will find it here.

Are you totally new to audio programming in general ? Or want to develop your own player someday ? Welcome.

Are you trying to get a quick prototype or proof of concept ffmpeg player developed in a few hours / days ? You can start here.

Are you a seasoned programmer who doesn't have the time or patience to figure it out on your own ? Good ... you don't have to.

I am *not* trying to educate those of you who have been taming ffmpeg for years :)

## Why ?

There simply aren't enough **beginner-level** demo projects or tutorials related to ffmpeg out there. It took me almost 2 whole years to finally learn enough to write this basic app.

It should not have to take so much effort for someone to be able to get a quick n dirty ffmpeg-based player up and running in a couple of hours. So, here goes my attempt to make it easier!

That said, I have shared links, below, to much bigger and more comprehensive resources which I myself learned from.

## How ?

Download the source and get it running in XCode. Open different types of music files, and see if/how it works.

Browse through the source code, which I have done my best to document. Tweak it to your heart's content, build it, run it, see (and hear) what happens!

Then, perhaps ... develop something much bigger and better yourself!

💡 **Tip** - To get the most out of this project, I recommend that you follow [targodan's tutorial](https://steemit.com/programming/@targodan/decoding-audio-files-with-ffmpeg) as you play with my demo app.

## Other helpful resources

* targodan's [ffmpeg decoding guide](https://steemit.com/programming/@targodan/decoding-audio-files-with-ffmpeg). Related code sample [here](https://gist.github.com/targodan/8cef8f2b682a30055aa7937060cd94b7). This tutorial is, hands down, the best one out there!

* [A detailed tutorial on the basics of ffmpeg](https://github.com/leandromoreira/ffmpeg-libav-tutorial) by leandromoreira.

* An [outdated but pretty detailed ffmpeg tutorial](https://dranger.com/ffmpeg/tutorial01.html) that others have recommended.

* rollmind's Swift/ffmpeg [demo app](https://github.com/rollmind/ffmpeg-swift-tutorial/tree/master/tutorial/tutorial) (somewhat outdated, but still helpful)

* Another [Swift player implementation](https://github.com/rollmind/SweetPlayer) by rollmind

* Sunlubo's [Swift wrapper for ffmpeg](https://github.com/sunlubo/SwiftFFmpeg)

* For a more full-fledged AVAudioEngine setup, I point you to my other (far bigger) project: [Aural Player](https://github.com/maculateConception/aural-player)

* A Swift ffmpeg [wrapper library](https://github.com/FFMS/ffms2) (that I'm not sure I understand but it should be mentioned).
