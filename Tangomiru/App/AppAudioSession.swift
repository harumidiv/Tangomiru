import AVFoundation
import os

/// アプリ全体の音の設定。読み上げと正解・不正解の音はマナーモードでも鳴らし、
/// 他のアプリで流している音楽は止めずに一緒に鳴らす
nonisolated enum AppAudioSession {
    static let category: AVAudioSession.Category = .playback
    static let options: AVAudioSession.CategoryOptions = [.mixWithOthers]

    /// setActive はメインスレッドで呼ぶと画面が固まることがあるので、専用のキューで順に行う
    private static let queue = DispatchQueue(label: "Tangomiru.audio-session", qos: .userInitiated)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tangomiru", category: "AudioSession")

    /// 起動時と、音を鳴らすものを作るたびに呼ぶ（割り込みなどで無効になっていても有効にし直すため）
    static func configure() {
        queue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(category, mode: .default, options: options)
                try session.setActive(true)
            } catch {
                logger.error("音声セッションを設定できませんでした: \(String(reflecting: error), privacy: .public)")
            }
        }
    }
}
