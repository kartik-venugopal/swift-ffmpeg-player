import AVFoundation

///
/// Helps map ffmpeg channel layout identifiers to their corresponding AVFoundation channel layout identifiers.
///
struct ChannelLayouts {
    
    static let layouts: [Int] = [
        CH_LAYOUT_MONO,
        CH_LAYOUT_STEREO,
        CH_LAYOUT_2POINT1,
        CH_LAYOUT_2_1,
        CH_LAYOUT_SURROUND,
        CH_LAYOUT_3POINT1,
        CH_LAYOUT_4POINT0,
        CH_LAYOUT_4POINT1,
        CH_LAYOUT_2_2,
        CH_LAYOUT_QUAD,
        CH_LAYOUT_5POINT0,
        CH_LAYOUT_5POINT1,
        CH_LAYOUT_5POINT0_BACK,
        CH_LAYOUT_5POINT1_BACK,
        CH_LAYOUT_6POINT0,
        CH_LAYOUT_6POINT0_FRONT,
        CH_LAYOUT_HEXAGONAL,
        CH_LAYOUT_6POINT1,
        CH_LAYOUT_6POINT1_BACK,
        CH_LAYOUT_6POINT1_FRONT,
        CH_LAYOUT_7POINT0,
        CH_LAYOUT_7POINT0_FRONT,
        CH_LAYOUT_7POINT1,
        CH_LAYOUT_7POINT1_WIDE,
        CH_LAYOUT_7POINT1_WIDE_BACK,
        CH_LAYOUT_OCTAGONAL,
        CH_LAYOUT_HEXADECAGONAL,
        CH_LAYOUT_STEREO_DOWNMIX]
    
    static let layoutsMap: [Int: AudioChannelLayoutTag] = [
        
        CH_LAYOUT_MONO: kAudioChannelLayoutTag_Mono,
        
        CH_LAYOUT_STEREO: kAudioChannelLayoutTag_Stereo,
        CH_LAYOUT_STEREO_DOWNMIX: kAudioChannelLayoutTag_Stereo,
        
        CH_LAYOUT_2POINT1: kAudioChannelLayoutTag_WAVE_2_1,
        CH_LAYOUT_2_1: kAudioChannelLayoutTag_DVD_2,
        CH_LAYOUT_SURROUND: kAudioChannelLayoutTag_WAVE_3_0,
        
        CH_LAYOUT_3POINT1: kAudioChannelLayoutTag_DVD_10,
        CH_LAYOUT_4POINT0: kAudioChannelLayoutTag_DVD_8,
        CH_LAYOUT_4POINT1: kAudioChannelLayoutTag_DVD_11,
        CH_LAYOUT_2_2: kAudioChannelLayoutTag_Quadraphonic,
        CH_LAYOUT_QUAD: kAudioChannelLayoutTag_WAVE_4_0_B,
        CH_LAYOUT_5POINT0: kAudioChannelLayoutTag_WAVE_5_0_A,
        CH_LAYOUT_5POINT1: kAudioChannelLayoutTag_WAVE_5_1_A,
        CH_LAYOUT_5POINT0_BACK: kAudioChannelLayoutTag_WAVE_5_0_B,
        CH_LAYOUT_5POINT1_BACK: kAudioChannelLayoutTag_WAVE_5_1_B,
        CH_LAYOUT_6POINT1: kAudioChannelLayoutTag_WAVE_6_1,
        CH_LAYOUT_7POINT1: kAudioChannelLayoutTag_WAVE_7_1,
        
        // ???
        CH_LAYOUT_6POINT0: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_6POINT0_FRONT: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_HEXAGONAL: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_6POINT1_BACK: kAudioChannelLayoutTag_MPEG_6_1_A,
        CH_LAYOUT_6POINT1_FRONT: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_7POINT0: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_7POINT0_FRONT: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_7POINT1_WIDE: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_7POINT1_WIDE_BACK: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_OCTAGONAL: kAudioChannelLayoutTag_WAVE_7_1,
        CH_LAYOUT_HEXADECAGONAL: kAudioChannelLayoutTag_WAVE_7_1]
    
    static func mapLayout(ffmpegLayout: Int) -> AVAudioChannelLayout {
        return AVAudioChannelLayout(layoutTag: layoutsMap[ffmpegLayout]!)!
    }
    
    static func printLayouts() {
        
        for layout in layouts.map({UInt64($0)}) {
            printLayout(layout, av_get_channel_layout_nb_channels(layout))
        }
    }
    
    static func printLayout(_ layout: UInt64, _ channelCount: Int32) {
        
        let layoutString = UnsafeMutablePointer<Int8>.allocate(capacity: 100)
        av_get_channel_layout_string(layoutString, 100, channelCount, layout)
        
        var channelNames: [String] = []
        for index in 0..<channelCount {
            channelNames.append(String(cString: av_get_channel_name(av_channel_layout_extract_channel(UInt64(layout), index))))
        }
        
        let ls = String(cString: layoutString)
        let ffLay = channelNames.joined(separator: " ")
        let avfLay = AVFLayout(ffLay)
        
        print("\nLayout:", layout, ls, ffLay)
        print("AVF Layout:", avfLay)
    }
    
    static func AVFLayout(_ lyt: String) -> String {
        
        return lyt
            .replacingOccurrences(of: "BL", with: "Rls")
            .replacingOccurrences(of: "BR", with: "Rrs")
            .replacingOccurrences(of: "BC", with: "Cs")
            .replacingOccurrences(of: "SL", with: "Ls")
            .replacingOccurrences(of: "SR", with: "Rs")
            .replacingOccurrences(of: "FLC", with: "Lc")
            .replacingOccurrences(of: "FRC", with: "Rc")
            .replacingOccurrences(of: "FL", with: "L")
            .replacingOccurrences(of: "FR", with: "R")
            .replacingOccurrences(of: "FC", with: "C")
        
    }
}
