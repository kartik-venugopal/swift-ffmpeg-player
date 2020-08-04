import Cocoa

///
/// Extensions for UI elements.
///

extension NSImageView {

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
