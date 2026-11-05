import Foundation
import os

/// 1文の和訳と解説（AI が作り、表示前に SentenceAnalysisValidator で検査する）
nonisolated struct SentenceAnalysis: Codable, Equatable, Sendable {
    var translation: String
    /// 文の構造・文法・表現のポイントを説明する日本語の文章
    var explanation: String
    /// 解説を作ろうとして失敗し、和訳だけになったか（保存せず、解説を作り直せるようにする）
    var isExplanationFailed = false

    private enum CodingKeys: String, CodingKey {
        case translation, explanation
    }
}

nonisolated enum SentenceStudyLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tangomiru", category: "SentenceStudy")
}

/// 1文の和訳と解説を作る（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol SentenceAnalyzer: Sendable {
    var isAvailable: Bool { get }
    /// 解説まで作れるか。false なら和訳だけを作る（解説は空）
    var canExplain: Bool { get }
    func analyze(_ sentence: String) async throws -> SentenceAnalysis
}

extension SentenceAnalyzer {
    nonisolated var canExplain: Bool { isAvailable }
}

nonisolated enum SentenceAnalysisValidator {
    /// 和訳が無ければ nil。解説は空でもよい
    static func validated(_ analysis: SentenceAnalysis) -> SentenceAnalysis? {
        let translation = analysis.translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translation.isEmpty else { return nil }
        return SentenceAnalysis(
            translation: translation,
            explanation: analysis.explanation.trimmingCharacters(in: .whitespacesAndNewlines),
            isExplanationFailed: analysis.isExplanationFailed
        )
    }
}

/// 1文を和訳する（PLaMo 実装とテスト用 Fake を差し替える）
nonisolated protocol SentenceTranslator: Sendable {
    var isAvailable: Bool { get }
    func translate(_ sentence: String) async throws -> String
}

/// 英文と和訳から解説を作る（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol SentenceExplainer: Sendable {
    var isAvailable: Bool { get }
    func explain(_ sentence: String, translation: String) async throws -> String
}

/// 和訳は翻訳専用モデル（PLaMo）で作り、解説はその和訳に合わせて別に作る。
/// 翻訳モデルが無い・失敗したときは fallback（和訳と解説をまとめて作る）に任せる。
/// 解説を作れない端末（Apple Intelligence 非対応）では和訳だけを返す。
/// 和訳はできたのに解説だけ失敗したときも、和訳は見せる（isExplanationFailed を立てて保存しない）
nonisolated struct TranslateThenExplainAnalyzer: SentenceAnalyzer {
    let translator: any SentenceTranslator
    let explainer: any SentenceExplainer
    let fallback: any SentenceAnalyzer

    var isAvailable: Bool { translator.isAvailable || fallback.isAvailable }
    var canExplain: Bool { explainer.isAvailable }

    func analyze(_ sentence: String) async throws -> SentenceAnalysis {
        guard translator.isAvailable else { return try await fallback.analyze(sentence) }
        let translation: String
        do {
            translation = try await translator.translate(sentence)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            SentenceStudyLog.logger.error("和訳モデルで訳せませんでした: \(String(reflecting: error), privacy: .public)")
            guard fallback.isAvailable else { throw error }
            return try await fallback.analyze(sentence)
        }
        guard !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            guard fallback.isAvailable else { return SentenceAnalysis(translation: "", explanation: "") }
            return try await fallback.analyze(sentence)
        }
        guard explainer.isAvailable else { return SentenceAnalysis(translation: translation, explanation: "") }
        do {
            let explanation = try await explainer.explain(sentence, translation: translation)
            return SentenceAnalysis(translation: translation, explanation: explanation)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            SentenceStudyLog.logger.error("解説を作れませんでした: \(String(reflecting: error), privacy: .public)")
            return SentenceAnalysis(translation: translation, explanation: "", isExplanationFailed: true)
        }
    }
}
