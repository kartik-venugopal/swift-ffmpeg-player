import AVFoundation

class Player {
    
    let audioEngine: AudioEngine = AudioEngine()
    var audioFormat: AVAudioFormat!
    
    var scheduler: Scheduler
    
    // TODO: Move this flag to the audio stream or codec
    var eof: Bool = false
    
    var scheduledBufferCount: Int = 0
    
    var playingFile: AudioFileContext!
    private var codec: AudioCodec! {playingFile.audioCodec}
    
    var state: PlayerState = .stopped
    
    var volume: Float {
        
        get {audioEngine.volume}
        set {audioEngine.volume = min(1, max(0, newValue))}
    }
    
    var seekPosition: Double {audioEngine.seekPosition}
    
    init() {
        
        scheduler = Scheduler(audioEngine: self.audioEngine)
        
        // Hack to eagerly initialize a lazy variable (so that the resampler is ready to go when required)
        _ = Resampler.instance
        
        NotificationCenter.default.addObserver(forName: .scheduler_playbackCompleted, object: nil, queue: nil, using: {notif in self.playbackCompleted()})
    }
    
    private func initialize(with file: AudioFileContext) throws {
        
        self.playingFile = file
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(file.audioCodec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        audioEngine.prepare(audioFormat)
        
        try scheduler.initialize(with: file)
    }
    
    func play(_ file: URL) {
        
        stopAndWait()
    
        guard let fileCtx = AudioFileContext(file) else {

            print("\nError opening file for playback: \(file.path)")
            return
        }
        
        do {
        
            try initialize(with: fileCtx)
            
            scheduler.initiateScheduling()
            beginPlayback()
            
        } catch {
            print("Player setup for file '\(file.path)' failed !")
        }
    }
    
    func seekToTime(_ seconds: Double, _ shouldBeginPlayback: Bool = true) {
        
        // BUG: After EOF is reached (but track is still playing last few seconds),
        // it should still be possible to seek backwards.
        
        guard playingFile != nil else {return}
        
        stopAndWait(false)
        scheduler.initiateScheduling(from: seconds)
        shouldBeginPlayback ? beginPlayback(from: seconds) : audioEngine.seekTo(seconds)
    }
    
    func togglePlayPause() {
        
        audioEngine.pauseOrResume()
        state = audioEngine.isPlaying ? .playing : .paused
    }
    
    func stop(_ playbackFinished: Bool = true) {
        
        state = .stopped
        audioEngine.stop()
        scheduler.stop()
        
        if playbackFinished {
            
            playingFile = nil
            audioEngine.playbackCompleted()
        }
    }
    
    private func stopAndWait(_ playbackFinished: Bool = true) {
        
        stop(playbackFinished)
        
        let time = measureTime {
            scheduler.stop()
        }
        
        print("\nWaited \(time * 1000) msec for previous ops to stop.")
    }
    
    private func beginPlayback(from seekPosition: Double = 0) {

        audioEngine.seekTo(seekPosition)
        audioEngine.play()
        state = .playing
    }
    
    private func playbackCompleted() {
        
        NSLog("Playback completed !!!\n")
        
        stop()
        audioEngine.playbackCompleted()
        playingFile?.destroy()
        
        NotificationCenter.default.post(name: .player_playbackCompleted, object: self)
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
