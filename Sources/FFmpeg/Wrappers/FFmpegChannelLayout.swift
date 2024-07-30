//
//  FFmpegChannelLayout.swift
//  FFmpegPlayer
//
//  Created by Kartik Venugopal on 29.07.24.
//

import AVFoundation

class FFmpegChannelLayout {
    
    let avChannelLayout: AVChannelLayout
    let numberOfChannels: Int32
    private(set) lazy var avfLayout: AVAudioChannelLayout = avChannelLayout.computedAVFLayout
    
    lazy var description: String = {
       
        let layoutStringPointer = UnsafeMutablePointer<Int8>.allocate(capacity: 100)
        defer {layoutStringPointer.deallocate()}
        
        withUnsafePointer(to: avChannelLayout) {ptr -> Void in
            av_channel_layout_describe(ptr, layoutStringPointer, 100)
        }
        
        return String(cString: layoutStringPointer).replacingOccurrences(of: "(", with: " (").capitalized
    }()
    
    init(avChannelLayout: AVChannelLayout) {
        
        self.avChannelLayout = avChannelLayout
        self.numberOfChannels = avChannelLayout.nb_channels
    }
}
