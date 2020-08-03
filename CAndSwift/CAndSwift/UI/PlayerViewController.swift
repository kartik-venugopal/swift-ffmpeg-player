import Cocoa
import AVFoundation

///
/// View controller for the player user interface.
///
/// Responds to all player control actions from the main menu and other user interface  elements (buttons, sliders, etc).
///
class PlayerViewController: NSViewController, NSMenuDelegate {
    
    @IBOutlet weak var btnPlayPause: NSButton!
    
    @IBOutlet weak var artView: NSImageView!
    @IBOutlet weak var lblTitle: NSTextField!
    
    @IBOutlet var txtMetadata: NSTextView!
    @IBOutlet var txtAudioInfo: NSTextView!
    
    @IBOutlet weak var seekSlider: NSSlider!
    @IBOutlet weak var lblSeekPos: NSTextField!
    private var seekPosTimer: Timer!
    
    @IBOutlet weak var volumeSlider: NSSlider!
    @IBOutlet weak var lblVolume: NSTextField!
    
    private var dialog: NSOpenPanel!
    private var fileCtx: AudioFileContext!
    private var trackInfo: TrackInfo!
    
    private let imgPlay: NSImage = NSImage(named: "Play")!
    private let imgPause: NSImage = NSImage(named: "Pause")!

    private let imgDefaultArt: NSImage = NSImage(named: "DefaultArt")!
    private let imgWarning: NSImage = NSImage(named: "Warning")!
    
    let audioFileExtensions: [String] = ["aac", "adts", "ac3", "aif", "aiff", "aifc", "caf", "flac", "mp3", "m4a", "m4b", "m4r", "snd", "au", "sd2", "wav", "oga", "ogg", "opus", "wma", "dsf", "mpc", "mp2", "ape", "wv", "dts", "mka"]
    
    let avFileTypes: [String] = [AVFileType.mp3.rawValue, AVFileType.m4a.rawValue, AVFileType.aiff.rawValue, AVFileType.aifc.rawValue, AVFileType.caf.rawValue, AVFileType.wav.rawValue, AVFileType.ac3.rawValue]
    
    private let player = Player()
    private let metadataReader = MetadataReader()
    
    private var seekInterval: Double = 5
    
    private var alert: NSAlert!
    fileprivate var recentFiles: [URL] = []
    
    override func viewDidLoad() {
        
        dialog = NSOpenPanel()
        
        dialog.message = "Choose an audio file"
        
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes        = audioFileExtensions + avFileTypes
        
        dialog.resolvesAliases = true;
        
        dialog.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Music/Aural-Test")
        
        player.volume = UserDefaults.standard.value(forKey: "playerVolume") as? Float ?? 0.5
        volumeSlider.floatValue = player.volume
        let intVolume = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(intVolume) %"
        
        txtMetadata.font = NSFont.systemFont(ofSize: 14)
        txtAudioInfo.font = NSFont.systemFont(ofSize: 14)
        
        artView.cornerRadius = 5
        
        // -----------
        
        alert = NSAlert()
        
        alert.window.title = "Please wait"
        alert.messageText = "Please wait"
        alert.informativeText = "The chosen file does not have duration information. Computing duration and building packet table to enable seeking ..."
        alert.alertStyle = .warning
        alert.icon = imgWarning
        
        let rect: NSRect = NSRect(x: alert.window.frame.origin.x, y: alert.window.frame.origin.y, width: alert.window.frame.width, height: 150)
        alert.window.setFrame(rect, display: true)
        
        alert.addButton(withTitle: "Ok")
        
        NotificationCenter.default.addObserver(forName: .player_playbackCompleted, object: nil, queue: nil, using: {notif in self.playbackCompleted()})
    }

    // Remember player volume on next app launch
    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.set(player.volume, forKey: "playerVolume")
    }
    
    @IBAction func openFileAction(_ sender: AnyObject) {
        
        guard dialog.runModal() == NSApplication.ModalResponse.OK, let url = dialog.url else {return}
        doOpenFile(url)
    }
    
    @IBAction func openFileFromMenuAction(_ sender: NSMenuItem) {
        doOpenFile(URL(fileURLWithPath: sender.title))
    }
    
    private func doOpenFile(_ url: URL) {
        
        recentFiles.removeAll(where: {$0 == url})
        recentFiles.isEmpty ? recentFiles.append(url) : recentFiles.insert(url, at: 0)
        
        playbackCompleted()
        
        let isRawStream: Bool = ["aac", "dts", "ac3"].contains(url.pathExtension.lowercased())
        
        DispatchQueue.global(qos: .userInteractive).async {
            
            guard let fileCtx = AudioFileContext(url) else {return}
            self.fileCtx = fileCtx
            
            let trackInfo: TrackInfo = self.metadataReader.readTrack(fileCtx)
            self.trackInfo = trackInfo
            
            DispatchQueue.main.async {
                
                self.showMetadata(url, trackInfo)
                self.showAudioInfo(trackInfo.audioInfo)
                
                if self.seekPosTimer == nil {
                    self.seekPosTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateSeekPosition(_:)), userInfo: nil, repeats: true)
                }
                
                self.updateSeekPosition(self)
                
                self.player.play(fileCtx)
                self.btnPlayPause.image = self.imgPause
                
                if isRawStream {
                    NSApplication.shared.abortModal()
                }
            }
        }
        
        if isRawStream {
            alert.runModal()
        }
    }
    
    private func showMetadata(_ file: URL, _ trackInfo: TrackInfo) {
        
        artView.image = trackInfo.art ?? imgDefaultArt
        
        txtMetadata.string = ""
        lblTitle.stringValue = trackInfo.displayedTitle ?? file.lastPathComponent
        
        if let title = trackInfo.title {
            txtMetadata.string += "Title:\n\(title)\n\n"
        }
        
        if let artist = trackInfo.artist {
            txtMetadata.string += "Artist:\n\(artist)\n\n"
        }
        
        if let album = trackInfo.album {
            txtMetadata.string += "Album:\n\(album)\n\n"
        }
        
        if let trackNum = trackInfo.displayedTrackNum {
            txtMetadata.string += "Track#:\n\(trackNum)\n\n"
        }
        
        if let discNum = trackInfo.displayedDiscNum {
            txtMetadata.string += "Disc#:\n\(discNum)\n\n"
        }
        
        if let genre = trackInfo.genre {
            txtMetadata.string += "Genre:\n\(genre)\n\n"
        }
        
        if let year = trackInfo.year {
            txtMetadata.string += "Year:\n\(year)\n\n"
        }
        
        for (key, value) in trackInfo.otherMetadata {
            txtMetadata.string += "\(key.capitalized):\n\(value)\n\n"
        }
        
        if txtMetadata.string.isEmpty {
            txtMetadata.string = "<No metadata found>"
        }
    }
    
    private func showAudioInfo(_ audioInfo: AudioInfo) {
        
        txtAudioInfo.string = ""
        
        txtAudioInfo.string += "File Type:\n\(audioInfo.fileType)\n\n"
        
        txtAudioInfo.string += "Codec:\n\(audioInfo.codec)\n\n"
        
        txtAudioInfo.string += "Duration:\n\(formatSecondsToHMS(audioInfo.duration, true))\n\n"
        
        txtAudioInfo.string += "Sample Rate:\n\(readableLongInteger(Int64(audioInfo.sampleRate))) Hz\n\n"
        
        txtAudioInfo.string += "Sample Format:\n\(audioInfo.sampleFormat.description)\n\n"
        
        txtAudioInfo.string += "Bit Rate:\n\(audioInfo.bitRate / 1000) kbps\n\n"
        
        switch audioInfo.channelCount {
        
        case 1:
            
            txtAudioInfo.string += "Channels:\nMono (1 ch)\n\n"
            
        case 2:
            
            txtAudioInfo.string += "Channels:\nStereo (2 ch)\n\n"
            
        default:
            
            txtAudioInfo.string += "Channels:\n\(audioInfo.channelCount)\n\n"
        }
        
        txtAudioInfo.string += "Frames:\n\(readableLongInteger(audioInfo.frameCount))\n\n"
    }
    
    @IBAction func playOrPauseAction(_ sender: AnyObject) {
        
        if self.fileCtx != nil {
            
            player.togglePlayPause()
            btnPlayPause.image = player.state == .playing ? imgPause : imgPlay
        }
    }
    
    @IBAction func stopAction(_ sender: AnyObject) {
        
        player.stop()
        playbackCompleted()
    }
    
    @IBAction func seekAction(_ sender: AnyObject) {
        
        if let trackInfo = self.trackInfo {
            
            let seekPercentage = seekSlider.doubleValue
            let duration = trackInfo.audioInfo.duration
            let newPosition = seekPercentage * duration / 100.0
            
            doSeekToTime(newPosition)
        }
    }
    
    @IBAction func seekForwardAction(_ sender: AnyObject) {
        doSeekToTime(player.seekPosition + seekInterval)
    }
    
    @IBAction func seekBackwardAction(_ sender: AnyObject) {
        doSeekToTime(player.seekPosition - seekInterval)
    }
    
    private func doSeekToTime(_ time: Double) {
        
        if self.trackInfo != nil {
            
            player.seekToTime(max(0, time))
            updateSeekPosition(self)
        }
    }
    
    @IBAction func volumeAction(_ sender: AnyObject) {
        
        player.volume = volumeSlider.floatValue
        
        let intVolume = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(intVolume) %"
    }
    
    @IBAction func decreaseVolumeAction(_ sender: AnyObject) {
        
        let currentVolume = player.volume
        player.volume = max(0, currentVolume - 0.05)
        
        volumeSlider.floatValue = player.volume
        
        let intVolume = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(intVolume) %"
    }
    
    @IBAction func increaseVolumeAction(_ sender: AnyObject) {
        
        let currentVolume = player.volume
        player.volume = min(1, currentVolume + 0.05)
        
        volumeSlider.floatValue = player.volume
        
        let intVolume = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(intVolume) %"
    }
    
    @IBAction func updateSeekPosition(_ sender: AnyObject) {
        
        let seekPos = player.seekPosition
        let duration = trackInfo?.audioInfo.duration ?? 0
        
        if self.fileCtx != nil {
            lblSeekPos.stringValue = "\(formatSecondsToHMS(seekPos))  /  \(formatSecondsToHMS(duration))"
        } else {
            lblSeekPos.stringValue = formatSecondsToHMS(seekPos)
        }
        
        let percentage = duration == 0 ? 0 : seekPos * 100 / duration
        seekSlider.doubleValue = percentage
    }
    
    private func playbackCompleted() {
        
        self.fileCtx = nil
        self.trackInfo = nil
        
        btnPlayPause.image = imgPlay
        lblSeekPos.stringValue = "0:00"
        artView.image = imgDefaultArt
        txtMetadata.string = ""
        txtAudioInfo.string = ""
        lblTitle.stringValue = ""
        seekSlider.doubleValue = 0
        
        seekPosTimer?.invalidate()
        seekPosTimer = nil
    }
    
    private func formatSecondsToHMS(_ timeSecondsDouble: Double, _ includeMsec: Bool = false) -> String {
        
        let timeSeconds = Int(round(timeSecondsDouble))
        
        let secs = timeSeconds % 60
        let mins = (timeSeconds / 60) % 60
        let hrs = timeSeconds / 3600
        
        if includeMsec {
            
            let msec = Int(round((timeSecondsDouble - floor(timeSecondsDouble)) * 1000))
            return hrs > 0 ? String(format: "%d : %02d : %02d.%03d", hrs, mins, secs, msec) : String(format: "%d : %02d.%03d", mins, secs, msec)
            
        } else {
            return hrs > 0 ? String(format: "%d : %02d : %02d", hrs, mins, secs) : String(format: "%d : %02d", mins, secs)
        }
    }
    
    private func readableLongInteger(_ num: Int64) -> String {
        
        let numString = String(num)
        var readableNumString: String = ""
        
        // Last index of numString
        let numDigits: Int = numString.count - 1
        
        var c = 0
        for eachCharacter in numString {
            readableNumString.append(eachCharacter)
            if (c < numDigits && (numDigits - c) % 3 == 0) {
                readableNumString.append(",")
            }
            c += 1
        }
        
        return readableNumString
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        
        menu.removeAllItems()
        
        for url in recentFiles {
            
            let action = #selector(self.openFileFromMenuAction(_:))
            
            let menuItem = NSMenuItem(title: url.path, action: action, keyEquivalent: "")
            menuItem.target = self
            menu.insertItem(menuItem, at: menu.items.count)
        }
    }
}

extension NSImageView {

    // Experimental code. Not currently in use.
    var cornerRadius: CGFloat {

        get {
            return self.layer?.cornerRadius ?? 0
        }

        set {

            if !self.wantsLayer {

                self.wantsLayer = true
                self.layer?.masksToBounds = true;
            }

            self.layer?.cornerRadius = newValue;
        }
    }
}

extension Notification.Name {
    
    static let player_playbackCompleted = NSNotification.Name("player.playbackCompleted")
}
