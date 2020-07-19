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
    
    private let player = Player()
    private var scheduler: Scheduler!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        scheduler = Scheduler(player)
        
        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/Infected Mushrooms - LSD.wma")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/wma/CD2/08 Track 8.wma")
        
        let time = measureTime {
            
            scheduler.playTrack(url)
         
//            if let trackInfo = Reader.readTrack(url) {
//
//                print(JSONMapper.map(trackInfo))
//                artView.image = trackInfo.art
//            }
            
//            Decoder.decodeAndPlay(url)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
            
            self.scheduler.seekToTime(url, 268, true)
        })
        
        print("Took \(time * 1000) msec")
    }
}

func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    return CFAbsoluteTimeGetCurrent() - startTime
}
