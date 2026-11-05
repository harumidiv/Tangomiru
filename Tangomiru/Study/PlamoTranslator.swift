import Foundation
import llama

/// PLaMo 3 Translate 0.8B（GGUF）を llama.cpp で動かし、英文を端末内で和訳する。
/// モデルは PlamoModelStore が Hugging Face からダウンロードして置く。まだ無ければ isAvailable が false になる
nonisolated struct PlamoTranslator: SentenceTranslator {
    static let modelName = "plamo-3-translate-0.8b-Q4_K_M"
    /// モデルの読み込みは重いので、アプリ全体で1つを使い回す
    static let shared = PlamoTranslator(modelURL: PlamoModelStore.defaultFileURL)

    private let modelURL: URL?
    private let engine: PlamoEngine?

    init(modelURL: URL?) {
        self.modelURL = modelURL
        engine = modelURL.map { PlamoEngine(modelURL: $0) }
    }

    /// ダウンロードが済めば使えるようになるので、毎回ファイルの有無を見る
    var isAvailable: Bool {
        guard let modelURL else { return false }
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

    func translate(_ sentence: String) async throws -> String {
        guard let engine, isAvailable else { throw PlamoError.modelNotFound }
        return try await engine.generate(Self.prompt(for: sentence), maxTokens: 512)
    }

    /// PFML3 形式の翻訳プロンプト。原文だけは特殊トークンとして解釈させない
    static func prompt(for sentence: String, targetLanguage: String = "ja") -> [PlamoPromptPart] {
        [
            .special("<|plamo:tag|>dataset<|plamo:msg|>translation<|plamo:tag|>input<|plamo:msg|>"),
            .text(sentence),
            .special("<|plamo:tag|>output<|plamo:key|>lang<|plamo:val|>\(targetLanguage)<|plamo:msg|>"),
        ]
    }
}

nonisolated enum PlamoPromptPart: Equatable, Sendable {
    /// <|plamo:tag|> などの特殊トークンを含む部分
    case special(String)
    /// 利用者が入力した文章（特殊トークンとして解釈しない）
    case text(String)
}

nonisolated enum PlamoError: Error {
    case modelNotFound
    case loadFailed
    case tokenizeFailed
    case promptTooLong
    case decodeFailed
    /// 生成の上限に達しても訳文が終わらなかった
    case truncated
}

/// llama.cpp のモデルとコンテキストを持つ。llama.cpp のコンテキストは同時に使えないので actor で順番に処理する
private actor PlamoEngine {
    /// 1文の翻訳には十分な長さ
    private static let contextLength: UInt32 = 2048
    /// 訳文の終わりを示すトークン
    private static let stopTokenTexts = ["<|plamo:tag|>", "<|plamo:bos|>"]

    private let modelURL: URL
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var vocab: OpaquePointer?
    private var stopTokens: Set<llama_token> = []

    init(modelURL: URL) {
        self.modelURL = modelURL
    }

    deinit {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
    }

    func generate(_ prompt: [PlamoPromptPart], maxTokens: Int) throws -> String {
        try loadIfNeeded()
        guard let context, let vocab else { throw PlamoError.loadFailed }
        llama_memory_clear(llama_get_memory(context), true)

        var tokens: [llama_token] = []
        for (index, part) in prompt.enumerated() {
            switch part {
            case .special(let text): tokens += try tokenize(text, addBOS: index == 0, parseSpecial: true)
            case .text(let text): tokens += try tokenize(text, addBOS: index == 0, parseSpecial: false)
            }
        }
        guard tokens.count + maxTokens <= Int(llama_n_ctx(context)) else { throw PlamoError.promptTooLong }

        let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy())

        let status = tokens.withUnsafeMutableBufferPointer {
            llama_decode(context, llama_batch_get_one($0.baseAddress, Int32($0.count)))
        }
        guard status == 0 else { throw PlamoError.decodeFailed }

        var bytes: [UInt8] = []
        for _ in 0..<maxTokens {
            try Task.checkCancellation()
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) || stopTokens.contains(token) {
                return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            bytes += piece(of: token, vocab: vocab)
            let status = withUnsafeMutablePointer(to: &token) { llama_decode(context, llama_batch_get_one($0, 1)) }
            guard status == 0 else { throw PlamoError.decodeFailed }
        }
        throw PlamoError.truncated
    }

    private func loadIfNeeded() throws {
        guard context == nil else { return }
        llama_backend_init()

        var modelParams = llama_model_default_params()
        #if targetEnvironment(simulator)
        // シミュレータの Metal では動かないことがあるので CPU で動かす
        modelParams.n_gpu_layers = 0
        #endif
        guard let model = llama_model_load_from_file(modelURL.path, modelParams) else { throw PlamoError.loadFailed }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = Self.contextLength
        contextParams.n_batch = Self.contextLength
        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw PlamoError.loadFailed
        }
        self.model = model
        self.context = context
        vocab = llama_model_get_vocab(model)
        stopTokens = Set(Self.stopTokenTexts.compactMap { text in
            guard let tokens = try? tokenize(text, addBOS: false, parseSpecial: true), tokens.count == 1 else { return nil }
            return tokens[0]
        })
    }

    private func tokenize(_ text: String, addBOS: Bool, parseSpecial: Bool) throws -> [llama_token] {
        let utf8Count = Int32(text.utf8.count)
        var tokens = [llama_token](repeating: 0, count: Int(utf8Count) + 2)
        let count = llama_tokenize(vocab, text, utf8Count, &tokens, Int32(tokens.count), addBOS, parseSpecial)
        guard count >= 0 else { throw PlamoError.tokenizeFailed }
        return Array(tokens.prefix(Int(count)))
    }

    private func piece(of token: llama_token, vocab: OpaquePointer) -> [UInt8] {
        var buffer = [CChar](repeating: 0, count: 64)
        var length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if length < 0 {
            buffer = [CChar](repeating: 0, count: Int(-length))
            length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        return buffer.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) }
    }
}
