import AVFoundation

/// クイズの正解音・不正解音を鳴らす（音の設定は AppAudioSession に従う。マナーモードでも鳴る）
final class QuizSoundPlayer {
    enum Sound: CaseIterable {
        case correct
        case wrong

        var resourceName: String {
            switch self {
            case .correct: "quiz_correct"
            case .wrong: "quiz_wrong"
            }
        }
    }

    private var players: [Sound: AVAudioPlayer] = [:]

    init() {
        AppAudioSession.configure()
        for sound in Sound.allCases {
            guard let url = Self.url(for: sound), let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
    }

    static func url(for sound: Sound, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: sound.resourceName, withExtension: "mp3")
    }

    func canPlay(_ sound: Sound) -> Bool {
        players[sound] != nil
    }

    func play(_ sound: Sound) {
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }

    func play(correct: Bool) {
        play(correct ? .correct : .wrong)
    }
}
