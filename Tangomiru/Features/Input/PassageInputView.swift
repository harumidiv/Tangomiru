import SwiftUI

struct PassageInputView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isExtracting = false
    @State private var result: ExtractionResult?

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
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("抽出") { Task { await extract() } }
                        .disabled(problem != nil || isExtracting || !services.status.isReady)
                }
            }
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

    private func extract() async {
        guard let pipeline = services.makePipeline() else { return }
        isExtracting = true
        result = await pipeline.run(bodyText)
        isExtracting = false
    }
}
