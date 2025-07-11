import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet private weak var playerView: UIView!
    @IBOutlet private weak var trimmerView: VideoTrimmer!
    
    private var player: AVPlayer!
    private var playerLayer: AVPlayerLayer!
    private var selectedTimeRange: CMTimeRange!
    private var timeObserverToken: Any?

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        doInitSetup()
    }
    
    private func doInitSetup() {
        guard let videoURL = Bundle.main.url(forResource: "duration 2", withExtension: "mp4") else { return }
        let asset = AVAsset(url: videoURL)
        player = AVPlayer(url: URL(fileURLWithPath: videoURL.path))
        playerLayer = AVPlayerLayer(player: player)
        playerView.layer.addSublayer(playerLayer)
        trimmerView.asset = asset
        trimmerView.minimumDuration = CMTime(seconds: 3, preferredTimescale: 600)
        
        selectedTimeRange = trimmerView.selectedRange
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, let range = self.selectedTimeRange else { return }
            self.trimmerView.progress = time
            if time >= range.end {
                self.player.pause()
            }
        }
        
        trimmerView.addTarget(self, action: #selector(trimmerValueChanged), for: VideoTrimmer.selectedRangeChanged)
        trimmerView.addTarget(self, action: #selector(trimmerBegan), for: VideoTrimmer.didBeginTrimming)
        trimmerView.addTarget(self, action: #selector(trimmerEnded), for: VideoTrimmer.didEndTrimming)
        trimmerView.addTarget(self, action: #selector(trimmerProgressChanged), for: VideoTrimmer.progressChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playerLayer.frame = playerView.bounds
    }
}

// MARK: - Action Methods
extension ViewController {
    @IBAction private func trimBtnTapped(_ sender: UIButton) {
        self.exportTrimmedVideo(from: self.trimmerView)
    }
    
    @objc private func trimmerValueChanged(_ sender: VideoTrimmer) {
        selectedTimeRange = sender.selectedRange
        player.seek(to: selectedTimeRange.start, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    @objc private func trimmerProgressChanged(_ sender: VideoTrimmer) {
        player.seek(to: CMTime(seconds: sender.progress.seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    @objc private func trimmerBegan(_ sender: VideoTrimmer) {
        self.player.pause()
    }

    @objc private func trimmerEnded(_ sender: VideoTrimmer) {
        self.player.play()
    }
}

// MARK: - Private Methods
extension ViewController {
    private func exportTrimmedVideo(from trimmer: VideoTrimmer) {
        guard let asset = trimmer.asset else { return }

        let selectedTimeRange = trimmer.selectedRange

        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed.mp4")

        try? FileManager.default.removeItem(at: outputURL)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        exportSession?.timeRange = selectedTimeRange

        if let videoComposition = trimmer.videoComposition {
            exportSession?.videoComposition = videoComposition
        }

        exportSession?.exportAsynchronously {
            switch exportSession?.status {
            case .completed:
                print("✅ Video trimmed and saved at: \(outputURL)")
            case .failed:
                print("❌ Failed: \(exportSession?.error?.localizedDescription ?? "Unknown error")")
            case .cancelled:
                print("⚠️ Cancelled")
            default:
                break
            }
        }
    }
}
