import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var playerVC: PlayerViewController!
    
    override init() {
        
        super.init()
        
        // Configure logging to a file.
//        freopen(NSHomeDirectory() + "/Music/ffmpeg-player.log", "a+", stderr)
    }

    ///
    /// Relays the event of application termination to the PlayerViewController, so that it may take appropriate actions.
    ///
    func applicationWillTerminate(_ notification: Notification) {
        playerVC.applicationWillTerminate(notification)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {true}
}

func measureTime(_ task: () -> Void) -> Double {
    
    let startTime = CFAbsoluteTimeGetCurrent()
    task()
    return CFAbsoluteTimeGetCurrent() - startTime
}
