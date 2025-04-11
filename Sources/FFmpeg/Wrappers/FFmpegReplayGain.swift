//
//  FFmpegReplayGain.swift
//  FFmpegPlayer
//
//  Created by Kartik Venugopal on 15.08.24.
//

import Foundation

struct FFmpegReplayGain {
    
    let trackGain: Float?
    let trackPeak: Float?
    let albumGain: Float?
    let albumPeak: Float?
    
    private static let key_trackGain: String = "replaygain_track_gain"
    private static let key_trackPeak: String = "replaygain_track_peak"
    private static let key_albumGain: String = "replaygain_album_gain"
    private static let key_albumPeak: String = "replaygain_album_peak"
    
    init(sideData: AVPacketSideData) {
        
        var trackGain: Float = 0
        var trackPeak: Float = 0
        var albumGain: Float = 0
        var albumPeak: Float = 0
        
        sideData.data.withMemoryRebound(to: AVReplayGain.self, capacity: 1) {replayGainPointer in
            
            let avReplayGain = replayGainPointer.pointee
            
            trackGain = Float(avReplayGain.track_gain) / 100000
            trackPeak = Float(avReplayGain.track_peak) / 100000
            
            albumGain = Float(avReplayGain.album_gain) / 100000
            albumPeak = Float(avReplayGain.album_peak) / 100000
        }
        
        self.trackGain = trackGain
        self.trackPeak = trackPeak
        self.albumGain = albumGain
        self.albumPeak = albumPeak
        
//        print("trackGain: \(trackGain)")
//        print("trackPeak: \(trackPeak)")
//        print("albumGain: \(albumGain)")
//        print("albumPeak: \(albumPeak)")
    }
    
    init?(metadata: [String: String]) {
        
        if let trackGainStr = metadata[Self.key_trackGain] {
            
            let numericStr = trackGainStr.replacingOccurrences(of: "dB", with: "").replacingOccurrences(of: " ", with: "")
            self.trackGain = Float(numericStr)
            
        } else {
            self.trackGain = nil
        }
        
        if let trackPeakStr = metadata[Self.key_trackPeak] {
            self.trackPeak = Float(trackPeakStr)
        } else {
            self.trackPeak = nil
        }
        
        if let albumGainStr = metadata[Self.key_albumGain] {
            
            let numericStr = albumGainStr.replacingOccurrences(of: "dB", with: "").replacingOccurrences(of: " ", with: "")
            self.albumGain = Float(numericStr)
            
        } else {
            self.albumGain = nil
        }
        
        if let albumPeakStr = metadata[Self.key_albumPeak] {
            self.albumPeak = Float(albumPeakStr)
        } else {
            self.albumPeak = nil
        }
        
        if trackGain == nil && trackPeak == nil && albumGain == nil && albumPeak == nil {
            return nil
        }
    }
}
