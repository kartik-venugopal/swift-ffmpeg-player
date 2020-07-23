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
    
    override init() {
    
        super.init()
//        freopen("/Volumes/MyData/Music/CAndSwift.log", "a+", stderr)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/0Rednex.ogg")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/D1.dsf")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/10.opus")
        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/02.mpc")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/10.opus")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/PerfectWorld.wma")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/Way.ogg")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/Infected Mushrooms - LSD.wma")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/Reiki2.ogg")
//        let url = URL(fileURLWithPath: "/Users/kven/Music/Aural-Test/Morning.ogg")

         let player = Player()
        player.decodeAndPlay(url)
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
//            player.seekToTime(url, 268, true)
//        })
        
//        guard let trackInfo: TrackInfo = Reader.readTrack(url) else {return}
//        print(JSONMapper.map(trackInfo))
//        artView.image = trackInfo.art
    }
}

func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    return CFAbsoluteTimeGetCurrent() - startTime
}
