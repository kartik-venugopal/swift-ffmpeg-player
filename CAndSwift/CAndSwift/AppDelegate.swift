//
//  AppDelegate.swift
//  CAndSwift
//
//  Created by Kven on 7/18/20.
//  Copyright © 2020 Kven. All rights reserved.
//

import Cocoa
import ffmpeg

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        av_register_all()
        avfilter_register_all()
        var formatContext = avformat_alloc_context()

        // Open the file and read its header. The codecs are not opened.
        // The function arguments are:
        // AVFormatContext (the component we allocated memory for),
        // url (filename),
        // AVInputFormat (if you pass NULL it'll do the auto detect)
        // and AVDictionary (which are options to the demuxer)
        // http://ffmpeg.org/doxygen/trunk/group__lavf__decoding.html#ga31d601155e9035d5b0e7efedc894ee49
        
        let url = URL(fileURLWithPath: "/Volumes/MyData/Music/Bourne.wav")
        
        let err = avformat_open_input(&formatContext, "/Volumes/MyData/Music/Bourne.wav", nil, nil)
        if err == 0 {
            
            let e2 = avformat_find_stream_info(formatContext, nil)
            if e2 == 0 {
                print("Duration is:", formatContext?.pointee.duration)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

