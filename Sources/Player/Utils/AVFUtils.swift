import AVFoundation

extension AVAudioFormat {

    ///
    /// A convenient way to instantiate an AVAudioFormat given an ffmpeg sample format, sample rate, and channel layout identifier.
    ///
    convenience init?(from sampleFormat: FFmpegSampleFormat, sampleRate: Int32, channelLayout: AVChannelLayout) {
        
        guard let channelLayout = FFmpegChannelLayoutsMapper.mapLayout(ffmpegLayout: channelLayout) else {
            return nil
        }
        
        var commonFmt: AVAudioCommonFormat
        
        switch sampleFormat.avFormat {
            
        case AV_SAMPLE_FMT_S16, AV_SAMPLE_FMT_S16P:
            
            commonFmt = .pcmFormatInt16
            
        case AV_SAMPLE_FMT_S32, AV_SAMPLE_FMT_S32P:
            
            commonFmt = .pcmFormatInt32
            
        case AV_SAMPLE_FMT_FLT, AV_SAMPLE_FMT_FLTP:
            
            commonFmt = .pcmFormatFloat32
            
        default:
            
            return nil
        }
        
        self.init(commonFormat: commonFmt, sampleRate: Double(sampleRate), interleaved: sampleFormat.isInterleaved, channelLayout: channelLayout)
    }
}

extension URL {
    
    private static let fileManager: FileManager = .default
    
    private var fileManager: FileManager {Self.fileManager}
    
    var lowerCasedExtension: String {
        pathExtension.lowercased()
    }
    
    // Checks if a file exists
    var exists: Bool {
        fileManager.fileExists(atPath: self.path)
    }
    
    var parentDir: URL {
        self.deletingLastPathComponent()
    }
    
    // Checks if a file exists
    static func exists(path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
    
    // Computes the size of a file, and returns a convenient representation
    var sizeBytes: UInt64 {
        
        do {
            
            let attr = try fileManager.attributesOfItem(atPath: path)
            return attr[.size] as? UInt64 ?? 0
            
        } catch let error as NSError {
            NSLog("Error getting size of file '%@': %@", path, error.description)
        }
        
        return .zero
    }
}
