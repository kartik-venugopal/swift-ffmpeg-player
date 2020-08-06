import Cocoa
import AVFoundation

///
/// View controller for the player user interface.
///
/// Responds to all player control actions from the main menu and other user interface  elements (buttons, sliders, etc).
///
class PlayerViewController: NSViewController, NSMenuDelegate {
    
    // Player controls that can be manipulated to control playback/volume.
    @IBOutlet weak var btnPlayPause: NSButton!
    @IBOutlet weak var seekSlider: NSSlider!
    @IBOutlet weak var volumeSlider: NSSlider!
    
    // Elements that display info for the currently playing track or player state
    @IBOutlet weak var artView: NSImageView!
    @IBOutlet weak var lblTitle: NSTextField!
    @IBOutlet var txtMetadata: NSTextView!
    @IBOutlet var txtAudioInfo: NSTextView!
    @IBOutlet weak var lblSeekPos: NSTextField!
    @IBOutlet weak var lblVolume: NSTextField!
    
    // Periodically updates the seek position label to show current track seek position.
    private var seekPosTimer: Timer!
    
    // Allows the user to choose an audio file to play.
    private var dialog: NSOpenPanel!
    
    // The play/pause button toggles between the following 2 images, depending on player state.
    private let imgPlay: NSImage = NSImage(named: "Play")!
    private let imgPause: NSImage = NSImage(named: "Pause")!
    
    // Image to be displayed when the current track has no cover art or there is no track currently playing.
    private let imgDefaultArt: NSImage = NSImage(named: "DefaultArt")!
    
    // Icon displayed in warning dialogs.
    private lazy var imgWarning: NSImage = NSImage(named: "Warning")!
    
    // Icon displayed in error dialogs.
    private lazy var imgError: NSImage = NSImage(named: "Error")!
    
    // The actual player that controls playback/volume.
    private let player = Player()
    
    // Reader that provides track metadata.
    private let metadataReader = MetadataReader()
    
    // Variables that temporarily hold state for the currently playing audio file/track.
    private var fileCtx: AudioFileContext!
    private var trackInfo: TrackInfo!
    
    // An ordered list of recently played files (used by the "Open Recent" menu).
    // The array is sorted by chronological order, i.e. most recent files first.
    private var recentFiles: [URL] = []
    
    // The time interval (in seconds) to be used when seeking backward/forward.
    private let seekInterval: Double = 5
    
    // The amount to be used when adjusting (increasing / decreasing) the player's volume.
    private let volumeAdjustment: Float = 0.05
    
    // A warning (modal) alert that is displayed to the user when an abnormal condition has occurred.
    private lazy var alert: NSAlert = {
        
        let alert = NSAlert()
        
        let rect: NSRect = NSRect(x: alert.window.frame.origin.x, y: alert.window.frame.origin.y, width: alert.window.frame.width, height: 150)
        alert.window.setFrame(rect, display: true)
        
        alert.addButton(withTitle: "Ok")
        
        return alert
    }()
    
    ///
    /// Initializes all UI elements when the owned view loads up.
    ///
    override func viewDidLoad() {

        initializeFileOpenDialog()
        
        // Remember the player volume from the previous app launch (or use a default value).
        player.volume = UserDefaults.standard.value(forKey: "player.volume") as? Float ?? 0.5
        volumeSlider.floatValue = player.volume
        
        let volumePercentage = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(volumePercentage) %"
        
        txtMetadata.font = NSFont.systemFont(ofSize: 14)
        txtAudioInfo.font = NSFont.systemFont(ofSize: 14)
        
        artView.cornerRadius = 3

        // Subscribe to notifications that the player has finished playing a track.
        NotificationCenter.default.addObserver(forName: .player_playbackCompleted, object: nil, queue: nil, using: {notif in self.playbackCompleted()})
    }
    
    private func initializeFileOpenDialog() {
        
        dialog = NSOpenPanel()
        
        dialog.message = "Choose an audio file"
        
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        
        dialog.canChooseDirectories    = false
        dialog.canCreateDirectories    = false
        
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes        = Constants.audioFileExtensions + Constants.avFileTypes
        
        dialog.resolvesAliases = true;
        
        dialog.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Music")
    }
    
    ///
    /// Persists settings to be remembered on the next app launch.
    /// This function is executed as the app is about to terminate.
    ///
    func applicationWillTerminate(_ notification: Notification) {
        
        // Remember the player's volume.
        UserDefaults.standard.set(player.volume, forKey: "player.volume")
    }
    
    ///
    /// Displays a file dialog to let the user choose an audio file for playback.
    ///
    @IBAction func openFileAction(_ sender: AnyObject) {
        
        guard dialog.runModal() == NSApplication.ModalResponse.OK, let url = dialog.url else {return}
        doOpenFile(url)
    }
    
    ///
    /// Responds to a user click on a menu item in the "Open Recent" menu, by opening the selected file for playback.
    ///
    /// - Parameter sender: The menu item that was clicked, and whose title points to a recently played file.
    ///
    @IBAction func openFileFromMenuAction(_ sender: NSMenuItem) {
        doOpenFile(URL(fileURLWithPath: sender.title))
    }
    
    ///
    /// Actually opens a file for playback, and updates the UI with track metadata.
    ///
    private func doOpenFile(_ url: URL) {
        
        player.stop()
        
        // Insert the opened file at the beginning of the "recent files" array (most recent item first)
        recentFiles.removeAll(where: {$0 == url})
        recentFiles.isEmpty ? recentFiles.append(url) : recentFiles.insert(url, at: 0)
        
        // Reset the UI prior to playing this newly chosen file.
        playbackCompleted()
        
        let isRawStream: Bool = Constants.rawAudioFileExtensions.contains(url.pathExtension.lowercased())
        
        // Spawn an asynchronous task on the global queue to initialize the file context, because we don't the
        // main thread to hang and render the UI unresponsive.
        DispatchQueue.global(qos: .userInteractive).async {
            
            guard let fileCtx = AudioFileContext(url) else {

                DispatchQueue.main.async {
                    self.showInvalidFileError(url)
                }
                
                return
            }
            
            self.fileCtx = fileCtx
            
            // First, read the track's metadata.
            let trackInfo: TrackInfo = self.metadataReader.readTrack(fileCtx)
            self.trackInfo = trackInfo
            
            // Perform UI updates back on the main thread (they cannot be done on any other thread).
            DispatchQueue.main.async {
                
                // Display the metadata that was read earlier.
                self.showMetadata(url, trackInfo)
                self.showAudioInfo(trackInfo.audioInfo)
                
                // Initiate the timer that will update the displayed seek position.
                if self.seekPosTimer == nil {
                    self.seekPosTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateSeekPosition(_:)), userInfo: nil, repeats: true)
                }
                
                self.updateSeekPosition(self)
                
                // Initiate playback of the file.
                self.player.play(fileCtx)
                self.btnPlayPause.image = self.imgPause
                
                // Dismiss the modal dialog if one was shown.
                if isRawStream {
                    NSApplication.shared.abortModal()
                }
            }
        }
        
        // If the file represents a raw audio stream such as DTS, inform the user that the player
        // needs to perform some processing before it can play the file, and that there will be a
        // delay.
        if isRawStream {
            showDurationComputationDelayAlert()
        }
    }
    
    ///
    /// Modally displays an alert informing the user that there is a delay in playback because the chosen audio file does not seem to have
    /// duration information, which now needs to be computed by reading through the file.
    ///
    private func showDurationComputationDelayAlert() {
        
        alert.window.title = "Please wait"
        alert.messageText = "Please wait"
        alert.informativeText = "The chosen file does not have duration information. Computing duration and building packet table to enable seeking ..."
        alert.alertStyle = .warning
        alert.icon = imgWarning
        
        alert.runModal()
    }
    
    ///
    /// Modally displays an alert informing the user that there is a delay in playback because the chosen audio file does not seem to have
    /// duration information, which now needs to be computed by reading through the file.
    ///
    private func showInvalidFileError(_ file: URL) {
        
        alert.window.title = "Failed to open file"
        alert.messageText = "Failed to open file: \(file.lastPathComponent)"
        alert.informativeText = "The chosen file does not seem to be a valid audio file.\nPlease inspect it and try again, or choose a different file to open."
        alert.alertStyle = .warning
        alert.icon = imgError
        
        alert.runModal()
    }
    
    ///
    /// Displays metadata for the currently playing track, e.g. artist / album / genre, cover art, etc.
    ///
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
    
    ///
    /// Displays technical audio data for the currently playing track, e.g. codec, sample rate, bit rate, bit depth, etc.
    ///
    private func showAudioInfo(_ audioInfo: AudioInfo) {
        
        txtAudioInfo.string = ""
        
        txtAudioInfo.string += "File Type:\n\(audioInfo.fileType)\n\n"
        
        txtAudioInfo.string += "Codec:\n\(audioInfo.codec)\n\n"
        
        txtAudioInfo.string += "Duration:\n\(NumericStringFormatter.formatSecondsToHMS(audioInfo.duration, includeMsec: true))\n\n"
        
        txtAudioInfo.string += "Sample Rate:\n\(NumericStringFormatter.readableLongInteger(Int64(audioInfo.sampleRate))) Hz\n\n"
        
        txtAudioInfo.string += "Sample Format:\n\(audioInfo.sampleFormat.description)\n\n"
        
        txtAudioInfo.string += "Bit Rate:\n\(NumericStringFormatter.readableLongInteger(audioInfo.bitRate / 1000)) kbps\n\n"
        
        txtAudioInfo.string += "Channel Layout:\n\(audioInfo.channelLayout)\n\n"
        
        txtAudioInfo.string += "Frames:\n\(NumericStringFormatter.readableLongInteger(audioInfo.frameCount))\n\n"
    }
    
    ///
    /// Responds to a click on the play / pause button, by toggling play / pause player state.
    ///
    @IBAction func playOrPauseAction(_ sender: AnyObject) {
        
        if self.fileCtx != nil {
            
            player.togglePlayPause()
            
            // Update button image to match the new player state
            btnPlayPause.image = player.state == .playing ? imgPause : imgPlay
        }
    }
    
    ///
    /// Responds to a click on the stop button, by stopping playback.
    ///
    @IBAction func stopAction(_ sender: AnyObject) {
        player.stop()
    }
    
    ///
    /// Responds to movement of the seek slider by asking the player to seek within the audio file.
    ///
    @IBAction func seekAction(_ sender: AnyObject) {
        
        if let trackInfo = self.trackInfo {
            
            // The seek slider's value (between 0 and 100) corresponds to
            // a percentage of the track's duration.
            
            let seekPercentage = seekSlider.doubleValue
            let duration = trackInfo.audioInfo.duration
            
            let newPosition = seekPercentage * duration / 100.0
            
            doSeekToTime(newPosition)
        }
    }
    
    ///
    /// Responds to a click on the seek forward button, by asking the player to seek forward a few seconds within the audio file.
    ///
    @IBAction func seekForwardAction(_ sender: AnyObject) {
        doSeekToTime(player.seekPosition + seekInterval)
    }
    
    ///
    /// Responds to a click on the seek backward button, by asking the player to seek backward a few seconds within the audio file.
    ///
    @IBAction func seekBackwardAction(_ sender: AnyObject) {
        doSeekToTime(player.seekPosition - seekInterval)
    }
    
    ///
    /// Actually performs a seek.
    ///
    /// - Parameter time: The desired new seek position within the audio file, specified in seconds.
    ///
    private func doSeekToTime(_ time: Double) {
        
        if self.trackInfo != nil {
            
            // Ensure that the seek time is not negative.
            player.seekToTime(max(0, time))
            
            // Immediately after a seek, update the seek position label and slider fields to reflect the updated seek position.
            updateSeekPosition(self)
        }
    }
    
    ///
    /// Responds to movement of the volume slider by asking the player to adjust its volume.
    ///
    @IBAction func volumeAction(_ sender: AnyObject) {
        
        player.volume = volumeSlider.floatValue
        
        // Convert the player's updated volume (in the range 0...1) to a percentage,
        // before displaying it.
        let volumePercentage = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(volumePercentage) %"
    }
    
    ///
    /// Responds to the menu item "Decrease Volume" by decreasing the player's volume by a small amount.
    ///
    @IBAction func decreaseVolumeAction(_ sender: AnyObject) {
        
        let currentVolume = player.volume
        
        // When computing a new volume, make sure that the adjustment does not result in a negative value.
        // i.e. the volume cannot be less than 0. If it is already 0, it should stay at 0.
        player.volume = max(0, currentVolume - volumeAdjustment)
        
        volumeSlider.floatValue = player.volume
        
        // Convert the player's updated volume (in the range 0...1) to a percentage,
        // before displaying it.
        let volumePercentage = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(volumePercentage) %"
    }
    
    ///
    /// Responds to the menu item "Increase Volume" by increasing the player's volume by a small amount.
    ///
    @IBAction func increaseVolumeAction(_ sender: AnyObject) {
        
        let currentVolume = player.volume
        
        // When computing a new volume, make sure that the adjustment does not result in a value > 1 (the maximum player volume).
        // i.e. the volume cannot be more than 1. If it is already 1, it should stay at 1.
        player.volume = min(1, currentVolume + volumeAdjustment)
        
        volumeSlider.floatValue = player.volume
        
        // Convert the player's updated volume (in the range 0...1) to a percentage,
        // before displaying it.
        let volumePercentage = Int(round(player.volume * 100))
        lblVolume.stringValue = "\(volumePercentage) %"
    }
    
    ///
    /// Updates the seek position label and slider to reflect the player's current seek position.
    /// This function is called periodically to continuously and automatically show the current seek position.
    ///
    @IBAction func updateSeekPosition(_ sender: AnyObject) {
        
        let seekPos = player.seekPosition
        let duration = trackInfo?.audioInfo.duration ?? 0
        
        if self.fileCtx != nil {
            lblSeekPos.stringValue = "\(NumericStringFormatter.formatSecondsToHMS(seekPos))  /  \(NumericStringFormatter.formatSecondsToHMS(duration))"
            
        } else {    // No track currently playing
            lblSeekPos.stringValue = "0:00"
        }
        
        let percentage = duration == 0 ? 0 : seekPos * 100 / duration
        seekSlider.doubleValue = percentage
    }
    
    ///
    /// Resets the UI after playback of a track has completed.
    ///
    private func playbackCompleted() {
        
        // De-reference the temporary variables holding current track info, so that they may be de-initialized.
        self.fileCtx = nil
        self.trackInfo = nil
        
        btnPlayPause.image = imgPlay
        lblSeekPos.stringValue = "0:00"
        artView.image = imgDefaultArt
        txtMetadata.string = ""
        txtAudioInfo.string = ""
        lblTitle.stringValue = ""
        seekSlider.doubleValue = 0
        
        // Stop the timer as it is no longer required (till another track begins playing).
        seekPosTimer?.invalidate()
        seekPosTimer = nil
    }
    
    ///
    /// Dynamically constructs the "Open Recent" menu based on which files were recently opened by the player during this app launch.
    ///
    func menuWillOpen(_ menu: NSMenu) {
        
        menu.removeAllItems()
        
        for url in recentFiles {
            
            let action = #selector(self.openFileFromMenuAction(_:))
            
            let menuItem = NSMenuItem(title: url.path, action: action, keyEquivalent: "")
            menuItem.target = self
            
            // Insert the item at the end of the menu (most recent item first).
            menu.insertItem(menuItem, at: menu.items.count)
        }
    }
}
