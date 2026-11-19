import AppKit
import AVFoundation
import SwiftUI

struct NativeVideoPlayerView: NSViewRepresentable {
    let manager: NativeVideoPlayerManager
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeNSView(context: Context) -> PlayerLayerHostNSView {
        let view = PlayerLayerHostNSView()
        view.playerLayer.player = manager.player
        view.playerLayer.videoGravity = videoGravity
        manager.attach(playerLayer: view.playerLayer)
        return view
    }

    func updateNSView(_ nsView: PlayerLayerHostNSView, context: Context) {
        if nsView.playerLayer.player !== manager.player {
            nsView.playerLayer.player = manager.player
        }
        if nsView.playerLayer.videoGravity != videoGravity {
            nsView.playerLayer.videoGravity = videoGravity
        }
    }
}

final class PlayerLayerHostNSView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}
