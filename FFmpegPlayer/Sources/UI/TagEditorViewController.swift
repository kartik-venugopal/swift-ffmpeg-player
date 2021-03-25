import Cocoa

class TagEditorViewController: NSViewController, NSMenuDelegate {

    @IBOutlet weak var lblFile: NSTextField!
    
    @IBOutlet weak var txtTitle: NSTextField!
    @IBOutlet weak var txtArtist: NSTextField!
    @IBOutlet weak var txtAlbum: NSTextField!
    @IBOutlet weak var txtGenre: NSTextField!
    
    // Reader that provides track metadata.
    private let metadataReader = MetadataReader()
    
    // Variables that temporarily hold state for the currently playing audio file/track.
    private var fileCtx: AudioFileContext!
    private var trackInfo: TrackInfo!
    
    // Allows the user to choose an audio file to play.
    private var dialog: NSOpenPanel!
    
    override func viewDidLoad() {
        initializeFileOpenDialog()
        doOpenFile(URL(fileURLWithPath: "/Users/kven/Music/01 - Secret Life.mp3"))
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
    
    private var url: URL?
    private var ctx: MetadataEditingContext?
    
    ///
    /// Displays a file dialog to let the user choose an audio file for playback.
    ///
    @IBAction func openFileAction(_ sender: AnyObject) {
        
        guard dialog.runModal() == NSApplication.ModalResponse.OK, let url = dialog.url else {return}
        
        self.url = url
        doOpenFile(url)
    }
    
    @IBAction func saveFileAction(_ sender: AnyObject) {
        
        if let ctx = self.ctx {
            
            ctx.title = txtTitle.stringValue.isEmpty ? nil : txtTitle.stringValue
            ctx.artist = txtArtist.stringValue.isEmpty ? nil : txtArtist.stringValue
            ctx.album = txtAlbum.stringValue.isEmpty ? nil : txtAlbum.stringValue
            ctx.genre = txtGenre.stringValue.isEmpty ? nil : txtGenre.stringValue
            
            ctx.save()
        }
    }
    
    
    ///
    /// Actually opens a file for playback, and updates the UI with track metadata.
    ///
    private func doOpenFile(_ url: URL) {
        
        lblFile.stringValue = url.path
        
        // Spawn an asynchronous task on the global queue to initialize the file context, because we don't the
        // main thread to hang and render the UI unresponsive.
        DispatchQueue.global(qos: .userInteractive).async {
            
            guard let fileCtx = AudioFileContext(forFile: url) else {
                return
            }
            
            self.fileCtx = fileCtx
            
            // First, read the track's metadata.
            let trackInfo: TrackInfo = self.metadataReader.readMetadata(forFile: fileCtx)
            self.trackInfo = trackInfo
            
            self.ctx = MetadataEditingContext(forFile: url)
            
            // Perform UI updates back on the main thread (they cannot be done on any other thread).
            DispatchQueue.main.async {
                
                // Display the metadata that was read earlier.
                self.showMetadata(url, trackInfo)
            }
        }
    }
    
    ///
    /// Displays metadata for the currently playing track, e.g. artist / album / genre, cover art, etc.
    ///
    private func showMetadata(_ file: URL, _ trackInfo: TrackInfo) {
        
        txtTitle.stringValue = trackInfo.displayedTitle ?? ""
        txtArtist.stringValue = trackInfo.artist ?? ""
        txtAlbum.stringValue = trackInfo.album ?? ""
        txtGenre.stringValue = trackInfo.genre ?? ""
//
//        if let artist = trackInfo.artist {
//            txtMetadata.string += "Artist:\n\(artist)\n\n"
//        }
//
//        if let album = trackInfo.album {
//            txtMetadata.string += "Album:\n\(album)\n\n"
//        }
//
//        if let trackNum = trackInfo.displayedTrackNum {
//            txtMetadata.string += "Track#:\n\(trackNum)\n\n"
//        }
//
//        if let discNum = trackInfo.displayedDiscNum {
//            txtMetadata.string += "Disc#:\n\(discNum)\n\n"
//        }
//
//        if let genre = trackInfo.genre {
//            txtMetadata.string += "Genre:\n\(genre)\n\n"
//        }
//
//        if let year = trackInfo.year {
//            txtMetadata.string += "Year:\n\(year)\n\n"
//        }
//
//        for (key, value) in trackInfo.otherMetadata {
//            txtMetadata.string += "\(key.capitalized):\n\(value)\n\n"
//        }
//
//        if txtMetadata.string.isEmpty {
//            txtMetadata.string = "<No metadata found>"
//        }
    }
}
