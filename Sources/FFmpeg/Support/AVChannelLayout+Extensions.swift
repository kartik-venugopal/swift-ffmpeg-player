//
//  AVChannelLayout+Extensions.swift
//  FFmpegPlayer
//
//  Created by Kartik Venugopal on 30.07.24.
//

import AVFoundation

extension AVChannelLayout {
    
    var computedAVFLayout: AVAudioChannelLayout {
        
        print("Order: \(self.order)")
        
        switch order {
            
        case AV_CHANNEL_ORDER_NATIVE:
            return avfLayoutForNativeOrder
            
        case AV_CHANNEL_ORDER_UNSPEC:
            return defaultLayoutForChannelCount
            
        case AV_CHANNEL_ORDER_CUSTOM:
            return avfLayoutForCustomOrder
            
        default:
            return .stereo
        }
    }
    
    private var avfLayoutForNativeOrder: AVAudioChannelLayout {
        mapChannelsToAVFLayout(nativeOrderChannels)
    }
    
    private var nativeOrderChannels: [AVChannel] {
       
        var theChannels: [AVChannel] = []
        
        let binaryString = String(u.mask, radix: 2)
        
        for (index, char) in binaryString.reversed().enumerated() {
            
            if char == "1" {
                theChannels.append(AVChannel(rawValue: index <= AV_CHAN_TOP_BACK_RIGHT.rawValue ? Int32(index) : Int32(index + 11)))
            }
        }
        
        return theChannels
    }
    
    private var avfLayoutForCustomOrder: AVAudioChannelLayout {
        mapChannelsToAVFLayout(customOrderChannels)
    }
    
    private var customOrderChannels: [AVChannel] {
       
        guard let customChannelsPtr = self.u.map else {return []}
        return (0..<Int(nb_channels)).map {customChannelsPtr[$0].id}
    }
    
    private func mapChannelsToAVFLayout(_ channels: [AVChannel]) -> AVAudioChannelLayout {
        
        var avfChannels: AudioChannelBitmap = .init()
        for avfChannel in channels.compactMap({$0.avfChannel}) {
            avfChannels.insert(avfChannel)
        }
        
        var layout = AudioChannelLayout.init()
        layout.mChannelBitmap = avfChannels
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelBitmap
        
        let avfLayout = AVAudioChannelLayout.init(layout: &layout)
        print("Muthu is: \(channels) \(layout.muthu)")
        return avfLayout
    }
    
    private var defaultLayoutForChannelCount: AVAudioChannelLayout {
        
        print("Def. layout for \(nb_channels) channel count: ...")
        
        switch self.nb_channels {
            
        case 1:
            return .mono
            
        case 2:
            return .stereo
            
        case 3:
            return AVAudioChannelLayout.init(layoutTag: kAudioChannelLayoutTag_WAVE_2_1)!
            
        case 4:
            return AVAudioChannelLayout.init(layoutTag: kAudioChannelLayoutTag_Quadraphonic)!
            
        case 5:
            return AVAudioChannelLayout.init(layoutTag: kAudioChannelLayoutTag_Pentagonal)!
            
        case 6:
            return AVAudioChannelLayout.init(layoutTag: kAudioChannelLayoutTag_WAVE_5_1_A)!
            
        case 7:
            return AVAudioChannelLayout.init(layoutTag: kAudioChannelLayoutTag_WAVE_6_1)!
            
        case 8:
            return AVAudioChannelLayout.init(layoutTag: kAudioChannelLayoutTag_WAVE_7_1)!
            
        default:
            return .stereo
        }
    }
}

extension AudioChannelLayout {
    
    static let sizeOfLayout: UInt32 = UInt32(MemoryLayout<AudioChannelLayout>.size)
    
    var muthu: String? {
        
        var layout: AudioChannelLayout = self
        
        var nameSize : UInt32 = 0
        var status = AudioFormatGetPropertyInfo(kAudioFormatProperty_ChannelLayoutName,
                                                Self.sizeOfLayout, &layout, &nameSize)
        
        if status != noErr {return nil}
        
        var formatName: CFString = String() as CFString
        status = AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutName,
                                        Self.sizeOfLayout, &layout, &nameSize, &formatName)
        
        if status != noErr {return nil}
        
        return String(formatName as NSString)
    }
}
