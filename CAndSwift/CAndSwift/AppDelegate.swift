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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
//        let arr = ConcurrentArray<Int>()
////        var arr = [UInt8]()
//        
//        for _ in 0..<100 {
//            
//            DispatchQueue.global(qos: .userInteractive).async {
//                arr.append(Int.random(in: 0...1000))
//            }
//        }
//        
//        usleep(200000)
//        
//        arr.sort(by: {$0 > $1})
//        print(arr.count, arr.array.prefix(100))
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
