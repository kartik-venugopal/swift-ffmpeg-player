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
    @IBOutlet weak var artView: NSImageView!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/Infected Mushrooms - LSD.wma")
        
        let time = measureTime {
         
//            if let trackInfo = Reader.readTrack(url) {
//
//                print(JSONMapper.map(trackInfo))
//                artView.image = trackInfo.art
//            }
            
            Decoder.decodeAndPlay(url)
        }
        
        print("Took \(time * 1000) msec")
    }
}

func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    return CFAbsoluteTimeGetCurrent() - startTime
}
