import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var playerVC: PlayerViewController!
    
    override init() {
        
        super.init()
        configureLoggingToAFile()
        
//        let ctx = MetadataEditingContext(forFile: URL(fileURLWithPath: "/Users/kven/Music/TagEdit/Bourne.mp3"))
    }
    
    private func configureLoggingToAFile() {
        freopen(NSHomeDirectory() + "/Music/ffmpeg-player.log", "a+", stderr)
    }

    ///
    /// Relays the event of application termination to the PlayerViewController, so that it may take appropriate actions.
    ///
    func applicationWillTerminate(_ notification: Notification) {
        playerVC.applicationWillTerminate(notification)
    }
    
    ///
    /// Returning true here will cause the app to terminate when the main window is closed instead of continuing to run.
    ///
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {true}
}
