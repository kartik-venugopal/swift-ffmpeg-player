import AVFoundation

class Player {
    
    let decoder: Decoder = Decoder()
    let audioEngine: AudioEngine = AudioEngine()
    
    var audioFormat: AVAudioFormat!
    var scheduledBufferCount: AtomicCounter<Int> = AtomicCounter<Int>()
    var eof: Bool {decoder.eof}
    
    var playingFile: AudioFileContext!
    var codec: AudioCodec! {playingFile.audioCodec}
    
    var state: PlayerState = .stopped
    
    var sampleCountForImmediatePlayback: Int32 = 0
    var sampleCountForDeferredPlayback: Int32 = 0
    
    let schedulingOpQueue: OperationQueue = {
        
        let queue = OperationQueue()
        queue.underlyingQueue = DispatchQueue.global(qos: .userInitiated)
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        
        return queue
    }()
    
    var volume: Float {
        
        get {audioEngine.volume}
        set {audioEngine.volume = min(1, max(0, newValue))}
    }
    
    var seekPosition: Double {audioEngine.seekPosition}
    
    init() {
        
        // Hack to eagerly initialize a lazy variable (so that the resampler is ready to go when required)
        _ = Resampler.instance
    }
    
    private func initialize(with file: AudioFileContext) throws {
        
        self.playingFile = file
        try decoder.initialize(with: file)
        
        let sampleRate: Int32 = codec.sampleRate
        let channelCount: Int32 = codec.params.channels
        let effectiveSampleRate: Int32 = sampleRate * channelCount
        
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channelLayout: ChannelLayouts.mapLayout(ffmpegLayout: Int(codec.channelLayout)))
        audioEngine.prepare(audioFormat)
        
        switch effectiveSampleRate {
            
        case 0..<100000:
            
            // 44.1 / 48 KHz stereo
            
            sampleCountForImmediatePlayback = 5 * sampleRate
            sampleCountForDeferredPlayback = 10 * sampleRate
            
        case 100000..<500000:
            
            // 96 / 192 KHz stereo
            
            sampleCountForImmediatePlayback = 3 * sampleRate
            sampleCountForDeferredPlayback = 10 * sampleRate
            
        default:
            
            // 96 KHz surround and higher sample rates
            
            sampleCountForImmediatePlayback = 2 * sampleRate
            sampleCountForDeferredPlayback = 7 * sampleRate
        }
    }
    
    func play(_ fileCtx: AudioFileContext) {
        
        playbackCompleted(false)
    
        do {
        
            try initialize(with: fileCtx)
            
            initiateScheduling()
            
            if scheduledBufferCount.value > 0 {
                beginPlayback()
            }
            
        } catch {
            print("Player setup for file '\(fileCtx.file.path)' failed !")
        }
    }
    
    func seekToTime(_ seconds: Double, _ shouldBeginPlayback: Bool = true) {
        
        guard playingFile != nil else {return}
        
        stop()
        initiateScheduling(from: seconds)
        
        if scheduledBufferCount.value > 0 {
            shouldBeginPlayback ? beginPlayback(from: seconds) : audioEngine.seekTo(seconds)
        }
    }
    
    func togglePlayPause() {
        
        audioEngine.pauseOrResume()
        state = audioEngine.isPlaying ? .playing : .paused
    }
    
    func stop() {
        
        state = .stopped
        
        stopScheduling()
        audioEngine.stop()
        decoder.stop()
    }
    
    func beginPlayback(from seekPosition: Double = 0) {

        audioEngine.seekTo(seekPosition)
        audioEngine.play()
        state = .playing
    }
    
    func playbackCompleted(_ notify: Bool = true) {
        
        NSLog("Playback completed !!!\n")
        
        stop()
        audioEngine.playbackCompleted()
        
        playingFile = nil

        if notify {
            NotificationCenter.default.post(name: .player_playbackCompleted, object: self)
        }
    }
}

enum PlayerState {
    
    // Not playing any track
    case stopped
    
    // Playing a track
    case playing
    
    // Paued while playing a track
    case paused
}
