import SwiftUI
import UIKit

/// 1文ずつ英文を読み、和訳と解説で学ぶ（Apple Intelligence 非対応端末では和訳だけ）
struct SentenceStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: SentenceStudyModel
    @State private var speaker = WordSpeaker()
    /// 単語をハイライトしてタップで意味や翻訳を出し、単語帳に追加できるようにする英文（プレビューでは nil）
    private let passage: Passage?
    /// 本文中の各文の位置。ハイライトの位置をその文の先頭が 0 になるよう変換するのに使う
    private let sentenceSpans: [TextSpan]

    /// 保存済みの日本語解説を使い、必要な文の解説を作って保存する
    init(passage: Passage) {
        self.init(
            model: SentenceStudyModel(
                sentences: SentenceSplitter.sentences(in: passage.body),
                saved: passage.sentenceAnalyses,
                analyzer: TranslateThenExplainAnalyzer.standard,
                onAnalyzed: { sentence, analysis in passage.saveSentenceAnalysis(analysis, for: sentence) }
            ),
            wordsFrom: passage
        )
    }

    /// プレビューなどで解説の作り方を差し替えるため。wordsFrom を渡すと、その単語をハイライトしてタップで意味を出す
    init(model: SentenceStudyModel, wordsFrom passage: Passage? = nil) {
        _model = State(initialValue: model)
        self.passage = passage
        sentenceSpans = passage.map { SentenceSplitter.slices(in: $0.body).map(\.span) } ?? []
    }

    /// 今の文のハイライト。単語帳に語を追加したらすぐ反映されるよう、毎回 passage から作る
    private var currentHighlights: [ReadingHighlight] {
        guard let passage, sentenceSpans.indices.contains(model.index) else { return [] }
        return ReadingSegmenter.highlights(passage.readingHighlights, within: sentenceSpans[model.index])
    }

    private var itemsByID: [UUID: VocabItem] { passage?.itemsByID ?? [:] }

    var body: some View {
        VStack(spacing: 16) {
            header
            if model.sentences.isEmpty {
                Spacer()
                ContentUnavailableView("読める文がありません", systemImage: "text.alignleft")
                Spacer()
            } else if model.isFinished {
                Spacer()
                ContentUnavailableView(
                    "おつかれさまでした", systemImage: "checkmark.circle",
                    description: Text("\(model.sentences.count)文を読み終えました")
                )
                Spacer()
                primaryButton("閉じる") { dismiss() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            sentenceCard
                            Text("※ 単語をタップすると、意味を確認できます")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 12)
                        }
                        if model.isRevealed { explanation }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                bottomButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(QuizPalette.background.ignoresSafeArea())
        .task { model.start() }
        .onChange(of: model.index) { _, _ in speaker.stop() }
        .onDisappear {
            speaker.stop()
            model.cancelAll()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(QuizPalette.surface))
                    .overlay(Circle().stroke(QuizPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            ProgressView(value: Double(min(model.index, model.sentences.count)), total: Double(max(model.sentences.count, 1)))
                .tint(.orange)
            Text("\(min(model.index + 1, model.sentences.count)) / \(model.sentences.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if let sentence = model.currentSentence {
                Button {
                    if speaker.isPlaying {
                        speaker.stop()
                    } else {
                        speaker.speak(sentence)
                    }
                } label: {
                    Image(systemName: speaker.isPlaying ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(speaker.isPlaying ? "読み上げを停止する" : "英文を読み上げる")
            }
        }
        .padding(.top, 8)
    }

    private var sentenceCard: some View {
        Text(VocabHighlight.attributed(model.currentSentence ?? "", highlights: currentHighlights, itemsByID: itemsByID))
            .font(.title2.weight(.semibold))
            .vocabTapActions(itemsByID: itemsByID, addingTo: passage)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20).fill(QuizPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(QuizPalette.border, lineWidth: 2))
    }

    @ViewBuilder
    private var explanation: some View {
        switch model.currentState {
        case .loaded(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                StudySection(title: "和訳") {
                    Text(analysis.translation).font(.body)
                }
                if analysis.isExplanationFailed {
                    StudySection(title: "解説") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("解説を作れませんでした").font(.body)
                            Button("もう一度試す", systemImage: "arrow.clockwise") { model.retry() }
                                .buttonStyle(.bordered)
                        }
                    }
                } else if !analysis.explanation.isEmpty {
                    StudySection(title: "解説") {
                        Text(analysis.explanation).font(.body)
                    }
                }
            }
            .transition(.opacity)
        case .failed:
            VStack(spacing: 12) {
                Text(model.canExplain ? "解説を作れませんでした" : "和訳を作れませんでした").font(.headline)
                Button("もう一度試す", systemImage: "arrow.clockwise") { model.retry() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .loading, nil:
            ProgressView(model.canExplain ? "解説を作成中…" : "和訳を作成中…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if model.isRevealed {
            let isLast = model.index == model.sentences.count - 1
            primaryButton(isLast ? "読み終える" : "次の文へ") { model.next() }
        } else {
            primaryButton(model.canExplain ? "和訳と解説を見る" : "和訳を見る") { withAnimation { model.reveal() } }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.orange)
    }
}

extension TranslateThenExplainAnalyzer {
    /// 和訳は PLaMo、解説は Foundation Models で作る
    static var standard: TranslateThenExplainAnalyzer {
        TranslateThenExplainAnalyzer(
            translator: PlamoTranslator.shared,
            explainer: FoundationModelsSentenceAnalyzer(),
            fallback: FoundationModelsSentenceAnalyzer()
        )
    }
}

private struct StudySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(QuizPalette.surface))
    }
}
