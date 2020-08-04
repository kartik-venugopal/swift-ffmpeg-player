import Cocoa

///
/// Extensions for UI elements.
///

extension NSImageView {

    ///
    /// Gives an NSImageView a rounded appearance.
    /// The cornerRadius value indicates the amount of rounding.
    ///
    var cornerRadius: CGFloat {

        get {self.layer?.cornerRadius ?? 0}

        set {

            if !self.wantsLayer {

                self.wantsLayer = true
                self.layer?.masksToBounds = true;
            }

            self.layer?.cornerRadius = newValue;
        }
    }
}
