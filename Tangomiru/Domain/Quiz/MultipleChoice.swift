/// AI には正解と誤答を別々に出させ、並べ替えと正解の番号はアプリ側で決める
/// （モデルに正解の番号を選ばせると、番号と内容が食い違うことがあるため）
nonisolated enum MultipleChoice {
    static func shuffled(correct: String, wrong: [String], using rng: inout SeededRandom) -> (choices: [String], answerIndex: Int) {
        let choices = ([correct] + wrong).shuffled(using: &rng)
        return (choices, choices.firstIndex(of: correct) ?? 0)
    }
}
