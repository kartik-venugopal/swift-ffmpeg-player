import AVFoundation

class Player {
    
    let audioEngine: AudioEngine = AudioEngine()
    var audioFormat: AVAudioFormat!
    
    var scheduler: Scheduler = Scheduler()
    
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
        
        // Hack to eagerly initialize a lazy variable (so that the resampler is ready to go when required)
        _ = Resampler.instance
    }
    
    private func initialize(with file: AudioFileContext) {
        
        self.playingFile = file
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(file.audioCodec.sampleRate), channels: AVAudioChannelCount(2), interleaved: false)!
        audioEngine.prepare(audioFormat)
    }
    
    func play(_ file: URL) {
        
        stopAndWait()
        
        do {
        
            guard let fileCtx = AudioFileContext(file) else {throw PlayerInitializationError()}
            initialize(with: fileCtx)
            
            try scheduler.initiateScheduling()
            beginPlayback()

        } catch {

            print("\nFFmpeg / audio engine setup failure !")
            return
        }
    }
    
    func seekToTime(_ seconds: Double, _ shouldBeginPlayback: Bool = true) {
        
        // BUG: After EOF is reached (but track is still playing last few seconds),
        // it should still be possible to seek backwards.
        
        guard playingFile != nil else {return}
        
        do {
        
            stopAndWait(false)
            try scheduler.initiateScheduling(from: seconds)
            shouldBeginPlayback ? beginPlayback(from: seconds) : audioEngine.seekTo(seconds)

        } catch {

            print("\nPlayer: Unable to seek !")
            return
        }
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
        
        NotificationCenter.default.post(name: .playbackCompleted, object: self)
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
