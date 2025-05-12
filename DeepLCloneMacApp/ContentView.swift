import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranslationViewModel
    let languages = ["auto","en","ja","fr","de","es","zh","ru","ko"]

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Input", selection: $viewModel.inputLanguage) {
                    Text("Auto").tag("auto")
                    ForEach(languages.filter { $0 != "auto" }, id: \.self) { lang in
                        Text(lang.uppercased()).tag(lang)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Button(action: { viewModel.swapLanguages() }) {
                    Image(systemName: "arrow.left.arrow.right")
                }

                Picker("Output", selection: $viewModel.outputLanguage) {
                    ForEach(languages.filter { $0 != "auto" }, id: \.self) { lang in
                        Text(lang.uppercased()).tag(lang)
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
        // onChange は不要。ViewModel のデバウンスが動作します。
    }
}

// MARK: - Swap languages helper
extension TranslationViewModel {
    func swapLanguages() {
        (inputLanguage, outputLanguage) = (outputLanguage, inputLanguage)
        translate()
    }
}
