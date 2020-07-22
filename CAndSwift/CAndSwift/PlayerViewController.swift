import Cocoa
import AVFoundation

class PlayerViewController: NSViewController {
    
    @IBOutlet weak var artView: NSImageView!
    @IBOutlet weak var lblTitle: NSTextField!
    
    @IBOutlet weak var txtMetadata: NSTextView!
    @IBOutlet weak var txtAudioInfo: NSTextView!
    
    private var dialog: NSOpenPanel!
    private var file: URL!
    
    let audioFileExtensions: [String] = ["aac", "adts", "ac3", "aif", "aiff", "aifc", "caf", "mp3", "m4a", "m4b", "m4r", "snd", "au", "sd2", "wav", "oga", "ogg", "opus", "wma", "dsf", "mpc", "mp2", "ape", "wv", "dts"]
    
    let avFileTypes: [String] = [AVFileType.mp3.rawValue, AVFileType.m4a.rawValue, AVFileType.aiff.rawValue, AVFileType.aifc.rawValue, AVFileType.caf.rawValue, AVFileType.wav.rawValue, AVFileType.ac3.rawValue]
    
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
        
        dialog.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Music")
    }
    
    @IBAction func openFileAction(_ sender: AnyObject) {
        
        if dialog.runModal() == NSApplication.ModalResponse.OK, let url = dialog.url {
            
            self.file = url
            if let trackInfo: TrackInfo = Reader.readTrack(url) {

                print(JSONMapper.map(trackInfo))
                artView.image = trackInfo.art
            }
        }
    }
    
    @IBAction func playOrPauseAction(_ sender: AnyObject) {
        
        Decoder.decodeAndPlay(file)
    }
    
    @IBAction func stopAction(_ sender: AnyObject) {
        
        Decoder.stop()
    }
}
