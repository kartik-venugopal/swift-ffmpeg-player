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
        avformat_network_init()
        let formatContext = avformat_alloc_context()
        print(formatContext)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

