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
        
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/CDImage.ape")
        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/test.mpc")
        
//        Decoder.decodeAndPlay(url)
        
        do {
            
            let dec = FFDecoder()
            try dec.initForFile(url)
            
            dec.decodeNSeconds(60)
            
        } catch {
            print("ERROR:")
            return
        }
        
        
        let time = measureTime {
            
//            if let trackInfo = Reader.readTrack(url) {
//
//                print(JSONMapper.map(trackInfo))
//                artView.image = trackInfo.art
//            }
            
//            scheduler.playTrack(url)
            
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
//
//            self.scheduler.seekToTime(url, 268, true)
//        })
        
        print("Took \(time * 1000) msec")
    }
}

func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    return CFAbsoluteTimeGetCurrent() - startTime
}
