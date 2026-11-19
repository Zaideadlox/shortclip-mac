import AVFoundation
import AVKit
import Foundation
import Observation

@MainActor
@Observable
final class NativeVideoPlayerManager: NSObject {
    let player: AVPlayer

    private(set) var currentURL: URL?
    private(set) var isPlaying: Bool = false
    private(set) var isBuffering: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPiPSupported: Bool = false
    private(set) var isPiPActive: Bool = false
    private(set) var loadError: String?

    var isMuted: Bool = false {
        didSet { player.isMuted = isMuted }
    }

    var volume: Float = 0.85 {
        didSet {
            player.volume = volume
            if volume > 0 && isMuted {
                isMuted = false
            }
        }
    }

    var playbackRate: Float = 1.0 {
        didSet {
            if isPlaying {
                player.rate = playbackRate
            }
        }
    }

    var loopEnabled: Bool = true
    var qualityPreference: VideoQualityPreference = .auto {
        didSet {
            player.currentItem?.preferredPeakBitRate = qualityPreference.preferredPeakBitRate
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    private var pipController: AVPictureInPictureController?
    private weak var attachedPlayerLayer: AVPlayerLayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var pipPossibleObservation: NSKeyValueObservation?

    override init() {
        self.player = AVPlayer()
        self.player.automaticallyWaitsToMinimizeStalling = true
        super.init()
        setupObservers()
    }

    func load(url: URL, autoPlay: Bool) {
        if currentURL == url {
            if autoPlay && !isPlaying {
                play()
            }
            return
        }

        currentURL = url
        loadError = nil
        currentTime = 0
        duration = 0
        isBuffering = true

        let item = AVPlayerItem(url: url)
        item.preferredPeakBitRate = qualityPreference.preferredPeakBitRate
        observeItem(item)

        player.replaceCurrentItem(with: item)
        player.isMuted = isMuted
        player.volume = volume

        if autoPlay {
            play()
        } else {
            pause()
        }
    }

    func attach(playerLayer: AVPlayerLayer) {
        if attachedPlayerLayer === playerLayer {
            return
        }
        attachedPlayerLayer = playerLayer

        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            Task { @MainActor [weak self] in
                self?.isPiPSupported = false
            }
            return
        }

        let controller = AVPictureInPictureController(playerLayer: playerLayer)
        controller?.delegate = self
        self.pipController = controller

        let initialPossible = controller?.isPictureInPicturePossible ?? false
        Task { @MainActor [weak self] in
            self?.isPiPSupported = initialPossible
        }

        pipPossibleObservation?.invalidate()
        pipPossibleObservation = controller?.observe(\.isPictureInPicturePossible, options: [.new]) { [weak self] ctrl, _ in
            let possible = ctrl.isPictureInPicturePossible
            Task { @MainActor [weak self] in
                if self?.isPiPSupported != possible {
                    self?.isPiPSupported = possible
                }
            }
        }
    }

    func play() {
        guard player.currentItem != nil else { return }
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func toggleMute() {
        isMuted.toggle()
    }

    func seek(toFraction fraction: Double) {
        guard duration > 0 else { return }
        let targetSeconds = min(max(fraction, 0), 1) * duration
        let cmTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = targetSeconds
    }

    func togglePictureInPicture() {
        guard let pipController else { return }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else if pipController.isPictureInPicturePossible {
            pipController.startPictureInPicture()
        }
    }

    func stopAndClear() {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        currentTime = 0
        duration = 0
        isBuffering = false
    }

    // MARK: - Observers

    private func setupObservers() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                guard let self else { return }
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                if let dur = self.player.currentItem?.duration.seconds, dur.isFinite, dur > 0 {
                    self.duration = dur
                }
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    break
                }
            }
        }
    }

    private func observeItem(_ item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObservation?.invalidate()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.loopEnabled {
                    self.player.seek(to: .zero)
                    self.play()
                } else {
                    self.isPlaying = false
                }
            }
        }

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            let status = observedItem.status
            let errorDesc = observedItem.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.loadError = nil
                    let dur = observedItem.duration.seconds
                    if dur.isFinite, dur > 0 {
                        self.duration = dur
                    }
                case .failed:
                    self.isBuffering = false
                    self.loadError = errorDesc ?? "Unable to play video."
                default:
                    break
                }
            }
        }
    }
}

extension NativeVideoPlayerManager: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            self.isPiPActive = true
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor in
            self.isPiPActive = false
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor in
            self.isPiPActive = false
        }
    }
}
