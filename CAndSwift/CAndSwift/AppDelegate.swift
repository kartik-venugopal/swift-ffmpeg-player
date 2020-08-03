//
//  AppDelegate.swift
//  CAndSwift
//
//  Created by Kven on 7/18/20.
//  Copyright © 2020 Kven. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var playerVC: PlayerViewController!
    
    override init() {
        
        super.init()
//        freopen("/Volumes/MyData/Music/CAndSwift.log", "a+", stderr)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
//        let file: URL = URL(fileURLWithPath: "/Volumes/MyData/Music/Aural-Test/sea.ac3")
//
//        let time = measureTime {
//            if let ctx = DurationEstimationContext(file) {
//            }
//        }
//
        //        print("\n", time * 1000, "msec")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        playerVC.applicationWillTerminate(notification)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {true}
}

func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    return CFAbsoluteTimeGetCurrent() - startTime
}
