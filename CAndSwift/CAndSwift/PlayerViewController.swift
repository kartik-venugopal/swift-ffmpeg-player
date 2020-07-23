import Cocoa
import AVFoundation

class PlayerViewController: NSViewController {
    
    @IBOutlet weak var btnPlayPause: NSButton!
    
    @IBOutlet weak var artView: NSImageView!
    @IBOutlet weak var lblTitle: NSTextField!
    
    @IBOutlet weak var txtMetadata: NSTextView!
    @IBOutlet weak var txtAudioInfo: NSTextView!
    
    @IBOutlet weak var volumeSlider: NSSlider!
    @IBOutlet weak var lblSeekPos: NSTextField!
    private var seekPosTimer: Timer!
    
    private var dialog: NSOpenPanel!
    private var file: URL!
    
    private let imgPlay: NSImage = NSImage(named: "Play")!
    private let imgPause: NSImage = NSImage(named: "Pause")!
    
    let audioFileExtensions: [String] = ["aac", "adts", "ac3", "aif", "aiff", "aifc", "caf", "mp3", "m4a", "m4b", "m4r", "snd", "au", "sd2", "wav", "oga", "ogg", "opus", "wma", "dsf", "mpc", "mp2", "ape", "wv", "dts"]
    
    let avFileTypes: [String] = [AVFileType.mp3.rawValue, AVFileType.m4a.rawValue, AVFileType.aiff.rawValue, AVFileType.aifc.rawValue, AVFileType.caf.rawValue, AVFileType.wav.rawValue, AVFileType.ac3.rawValue]
    
    private let player = Player()
    
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
        
        player.volume = 0
        volumeSlider.floatValue = player.volume
        
        txtMetadata.font = NSFont.systemFont(ofSize: 16)
    }
    
    @IBAction func openFileAction(_ sender: AnyObject) {
        
        if dialog.runModal() == NSApplication.ModalResponse.OK, let url = dialog.url {
            
            self.file = url
            if let trackInfo: TrackInfo = Reader.readTrack(url) {

                print(JSONMapper.map(trackInfo))
                artView.image = trackInfo.art
                
                txtMetadata.string = ""
                lblTitle.stringValue = trackInfo.displayedTitle ?? url.deletingPathExtension().lastPathComponent
                
                if let title = trackInfo.title {
                    txtMetadata.string += "Title:  \(title)\n\n"
                }
                
                if let artist = trackInfo.artist {
                    txtMetadata.string += "Artist:  \(artist)\n\n"
                }
                
                if let album = trackInfo.album {
                    txtMetadata.string += "Album:  \(album)\n\n"
                }
                
                if let trackNum = trackInfo.displayedTrackNum {
                    txtMetadata.string += "Track:  \(trackNum)\n\n"
                }
                
                if let discNum = trackInfo.displayedDiscNum {
                    txtMetadata.string += "Disc:  \(discNum)\n\n"
                }
                
                if let genre = trackInfo.genre {
                    txtMetadata.string += "Genre:  \(genre)\n\n"
                }
                
                if let year = trackInfo.year {
                    txtMetadata.string += "Year:  \(year)\n\n"
                }
                
                for (key, value) in trackInfo.otherMetadata {
                    txtMetadata.string += "\(key.capitalized):  \(value)\n\n"
                }
                
                player.decodeAndPlay(url)
                btnPlayPause.image = imgPause
                
                if seekPosTimer == nil {
                    seekPosTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateSeekPosition(_:)), userInfo: nil, repeats: true)
                }
            }
        }
    }
    
    @IBAction func playOrPauseAction(_ sender: AnyObject) {
        
        if self.file != nil {
            
            player.togglePlayPause()
            btnPlayPause.image = player.state == .playing ? imgPause : imgPlay
        }
    }
    
    @IBAction func stopAction(_ sender: AnyObject) {
        
        player.stop()
        btnPlayPause.image = imgPlay
    }
    
    @IBAction func volumeAction(_ sender: AnyObject) {
        player.volume = volumeSlider.floatValue
    }
    
    @IBAction func updateSeekPosition(_ sender: AnyObject) {
        lblSeekPos.stringValue = formatSecondsToHMS(Int(round(player.seekPosition)))
    }
    
    private func formatSecondsToHMS(_ timeSeconds: Int, _ includeMinusPrefix: Bool = false) -> String {
        
        let secs = timeSeconds % 60
        let mins = (timeSeconds / 60) % 60
        let hrs = timeSeconds / 3600
        
        return hrs > 0 ? String(format: "%@%d:%02d:%02d", includeMinusPrefix ? "- " : "", hrs, mins, secs) : String(format: "%@%d:%02d", includeMinusPrefix ? "- " : "", mins, secs)
    }
}
