import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranslationViewModel
    let languages = ["auto","en","ja","fr","de","es","zh","ru","ko"]
    let models = ["gpt-3.5-turbo","gpt-4","gpt-4o-mini", "gpt-4.1-nano"] // 必要に応じて追加

    var body: some View {
        VStack(spacing: 12) {
            // ─── 設定セクション ─────────────────
            GroupBox("Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("API Key", text: $viewModel.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("API Base URL", text: $viewModel.apiBaseURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Picker("Model", selection: $viewModel.model) {
                        ForEach(models, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(8)
            }
            // ────────────────────────────────────

            HStack {
                Picker("Input", selection: $viewModel.inputLanguage) {
                    Text("Auto").tag("auto")
                    ForEach(languages.filter { $0 != "auto" }, id: \.self) {
                        Text($0.uppercased()).tag($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Button { viewModel.swapLanguages() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }

                Picker("Output", selection: $viewModel.outputLanguage) {
                    ForEach(languages.filter { $0 != "auto" }, id: \.self) {
                        Text($0.uppercased()).tag($0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.bottom, 8)

            HStack {
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .border(Color.gray)
                TextEditor(text: $viewModel.translatedText)
                    .font(.body)
                    .border(Color.gray)
            }
        }
        .padding()
    }
}

// MARK: - Swap languages helper
extension TranslationViewModel {
    func swapLanguages() {
        (inputLanguage, outputLanguage) = (outputLanguage, inputLanguage)
        translate()
    }
}
