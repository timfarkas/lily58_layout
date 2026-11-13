// keyhelp: hold a hotkey -> keymap overlay on liquid glass; release -> gone.
// usage: keyhelp <image-path> [hotkey]     hotkey default "F19"; modifiers like "cmd+shift+F19"
// Carbon RegisterEventHotKey gives press AND release events and needs no accessibility permission.
// fails loudly (exit 1) on a missing image, unknown key/modifier, or a second running instance.
// ASSUMPTION: macOS 26+ (NSGlassEffectView). older macOS won't compile — by design, no fallback.
import AppKit
import Carbon.HIToolbox

let KEYS: [String: Int] = [
    "F13": kVK_F13, "F14": kVK_F14, "F15": kVK_F15, "F16": kVK_F16,
    "F17": kVK_F17, "F18": kVK_F18, "F19": kVK_F19, "F20": kVK_F20,
    "SPACE": kVK_Space, "ESC": kVK_Escape, "/": kVK_ANSI_Slash,
]
let MODS: [String: Int] = ["cmd": cmdKey, "shift": shiftKey, "alt": optionKey, "opt": optionKey, "ctrl": controlKey]

func die(_ msg: String) -> Never {
    FileHandle.standardError.write("keyhelp: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

enum Overlay {  // statics, not top-level vars: the Carbon C callback can't capture context
    static var panel: NSPanel!
    static var image: NSImage!
    static var imageView: NSImageView!
    static var dim: NSView!
    static let pad: CGFloat = 18
    static let fill: CGFloat = 0.75  // max fraction of the screen (either axis) the overlay may take

    static func setup(_ img: NSImage) {
        image = img
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let glass = NSGlassEffectView()
        glass.cornerRadius = 34
        glass.tintColor = NSColor.black.withAlphaComponent(0.3)
        // plain frames, no auto layout: the 3x png's intrinsic size fought the constraints (clipped, then shrunken)
        imageView = NSImageView()
        imageView.image = img
        imageView.imageScaling = .scaleProportionallyUpOrDown
        // own dark layer inside the glass: tintColor alone came out milky over bright wallpapers
        dim = NSView()
        dim.wantsLayer = true
        dim.layer?.backgroundColor = NSColor(white: 0.04, alpha: 0.55).cgColor
        glass.contentView = dim
        dim.addSubview(imageView)
        panel.contentView = glass
    }

    static func show() {
        // center on the screen under the mouse; fit image (+padding) into `fill` of it
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let vf = screen.visibleFrame
        let s = min((vf.width * fill - 2 * pad) / image.size.width, (vf.height * fill - 2 * pad) / image.size.height)
        let w = image.size.width * s + 2 * pad, h = image.size.height * s + 2 * pad
        panel.setFrame(NSRect(x: vf.midX - w / 2, y: vf.midY - h / 2, width: w, height: h), display: false)
        dim.frame = NSRect(x: 0, y: 0, width: w, height: h)
        imageView.frame = NSRect(x: pad, y: pad, width: w - 2 * pad, height: h - 2 * pad)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
    }

    static func hide() {
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.1; panel.animator().alphaValue = 0 },
                                             completionHandler: { panel.orderOut(nil) })
    }
}

// single instance: Carbon happily lets two processes grab the same hotkey (-> stacked overlays), so lock instead.
// the fd stays open for the process lifetime; the kernel drops the lock when we die.
let lockFd = open("/tmp/keyhelp.lock", O_CREAT | O_RDWR, 0o644)
guard lockFd >= 0, flock(lockFd, LOCK_EX | LOCK_NB) == 0 else { die("already running (lock /tmp/keyhelp.lock held)") }

let args = CommandLine.arguments
guard args.count >= 2 else { die("usage: keyhelp <image-path> [hotkey, default F19]") }
guard let img = NSImage(contentsOfFile: args[1]) else { die("can't load image \(args[1])") }
let hotkey = args.count >= 3 ? args[2] : "F19"

var parts = hotkey.split(separator: "+").map(String.init)
let keyName = parts.removeLast()
guard let keyCode = KEYS[keyName.uppercased()] else { die("unknown key \(keyName); known: \(KEYS.keys.sorted())") }
let mods = parts.reduce(0) { acc, m in
    guard let v = MODS[m.lowercased()] else { die("unknown modifier \(m); known: \(MODS.keys.sorted())") }
    return acc | v
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no dock icon, never steals focus
Overlay.setup(img)

var spec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
    GetEventKind(event) == UInt32(kEventHotKeyPressed) ? Overlay.show() : Overlay.hide()
    return noErr
}, 2, &spec, nil, nil)

var ref: EventHotKeyRef?
let status = RegisterEventHotKey(UInt32(keyCode), UInt32(mods), EventHotKeyID(signature: 0x6b68_6c70, id: 1),
                                 GetApplicationEventTarget(), 0, &ref)
guard status == noErr else { die("RegisterEventHotKey(\(hotkey)) failed: \(status)") }
print("keyhelp: hold \(hotkey) to show \(args[1])")
app.run()
