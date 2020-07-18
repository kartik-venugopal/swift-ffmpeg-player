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
        
        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/14.opus")
        
        if let trackInfo = Reader.readTrack(url) {
            print(JSONMapper.map(trackInfo))
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

