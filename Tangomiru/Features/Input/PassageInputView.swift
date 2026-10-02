import SwiftUI

struct PassageInputView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isExtracting = false
    @State private var progressMessage = "単語を抽出中…"
    @AppStorage("includeBasicWords") private var includeBasicWords = false
    @State private var result: ExtractionResult?
    @State private var extractionTask: Task<Void, Never>?

    private var problem: PassageInput.Problem? { PassageInput.validate(bodyText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        EnglishSourcesView()
                    } label: {
                        Label("英文を探す（英語ニュースのサイト）", systemImage: "globe")
                    }
                }
                Section {
                    Toggle("基本語も出題に含める", isOn: $includeBasicWords)
                } footer: {
                    Text("基本語は中学レベルの約2,000語（people、important など）。オンでも the や is などの機能語は含めません")
                }
                Section("タイトル（省略可）") {
                    TextField("例: ニュース記事", text: $title)
                }
                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 240)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("英文")
                } footer: {
                    footer
                }
            }
            .disabled(isExtracting)
            .overlay {
                if isExtracting {
                    ProgressView(progressMessage)
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .navigationTitle("英文を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        extractionTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("抽出", action: startExtraction)
                        .disabled(problem != nil || isExtracting || !services.status.isReady)
                }
            }
            // 全画面広告が重なると onDisappear が呼ばれるため、そこではキャンセルしない。
            // 抽出中はスワイプで閉じられないようにし、止めるのは「キャンセル」ボタンだけにする
            .interactiveDismissDisabled(isExtracting)
            .onAppear { services.extractionAd.preload() }
            .navigationDestination(item: $result) { result in
                ExtractionReviewView(
                    title: PassageInput.title(title, body: bodyText),
                    passageBody: bodyText,
                    result: result
                ) {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch problem {
        case .empty:
            Text("英文を貼り付けてください")
        case .tooLong:
            Text("長すぎます（\(bodyText.count) / \(PassageInput.maxLength)文字）").foregroundStyle(.red)
        case nil:
            Text("\(bodyText.count) / \(PassageInput.maxLength)文字")
        }
        if case .failed(let message) = services.status {
            Text(message).foregroundStyle(.red)
        }
    }

    /// 二度押しで2回走らないよう、isExtracting はタップと同時に立てる
    private func startExtraction() {
        guard !isExtracting, let pipeline = services.makePipeline(includeBasicWords: includeBasicWords) else { return }
        isExtracting = true
        progressMessage = "単語を抽出中…"
        let body = bodyText
        extractionTask = Task {
            // 抽出の待ち時間に広告を出す（広告を閉じても抽出中なら進捗の表示が残る）
            let extracted = await ExtractionWithAd.run(ad: services.extractionAd) {
                var extracted = await pipeline.run(body)
                // Apple Intelligence 対応端末では、文章の内容を問う問題も一緒に作って保存する
                let generator = FoundationModelsComprehensionGenerator()
                if !Task.isCancelled && generator.isAvailable && !extracted.items.isEmpty {
                    progressMessage = "文章の質問を作成中…"
                    extracted.comprehension = await ComprehensionBuilder(passage: body).buildAll(using: generator)
                }
                return extracted
            }
            isExtracting = false
            guard !Task.isCancelled else { return }
            result = extracted
        }
    }
}
