import AVFoundation

/// アプリ全体の音の設定。読み上げと正解・不正解の音はマナーモードでも鳴らし、
/// 他のアプリで流している音楽は止めずに一緒に鳴らす
enum AppAudioSession {
    static let category: AVAudioSession.Category = .playback
    static let options: AVAudioSession.CategoryOptions = [.mixWithOthers]

    static func configure() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(category, mode: .default, options: options)
        try? session.setActive(true)
    }
}
