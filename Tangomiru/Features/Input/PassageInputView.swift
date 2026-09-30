import SwiftUI

struct PassageInputView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isExtracting = false
    @State private var result: ExtractionResult?
    @State private var extractionTask: Task<Void, Never>?

    private var problem: PassageInput.Problem? { PassageInput.validate(bodyText) }

    var body: some View {
        NavigationStack {
            Form {
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
                    ProgressView("抽出中…")
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
            .onDisappear { extractionTask?.cancel() }
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
        guard !isExtracting, let pipeline = services.makePipeline() else { return }
        isExtracting = true
        let body = bodyText
        extractionTask = Task {
            let extracted = await pipeline.run(body)
            isExtracting = false
            guard !Task.isCancelled else { return }
            result = extracted
        }
    }
}
