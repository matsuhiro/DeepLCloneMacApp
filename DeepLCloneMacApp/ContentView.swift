import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @State private var showingSettings = false
    let languages = ["auto","en","ja","fr","de","es","zh","ru","ko"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 設定ボタン＋言語切替
            HStack {
                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings")

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

            // 入力／出力テキストエリア
            HStack(spacing: 8) {
                // 左側入力エリアにオーバーレイ
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .border(Color.gray)
                
                // 右側翻訳結果エリア
                ZStack {
                    TextEditor(text: $viewModel.translatedText)
                        .font(.body)
                        .border(Color.gray)
                    
                    if viewModel.isLoading {
                        // 半透明背景 + スピナー
                        Color.black.opacity(0.15)
                            .edgesIgnoringSafeArea(.all)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            .frame(minHeight: 300)  // 必要に応じて高さ調整
        }
        .padding()
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
}

/// 設定画面
struct SettingsView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @Environment(\.presentationMode) var presentation
    @State private var newModel: String = ""

    var body: some View {
        NavigationView {
            Form {
                // ─── API 設定 ─────────────────────
                Section(header: Text("API Settings")) {
                    SecureField("API Key", text: $viewModel.apiKey)
                    TextField("API Base URL", text: $viewModel.apiBaseURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // ─── 現在利用するモデルの選択 ────────────
                Section(header: Text("Current Model")) {
                    Picker("Use Model", selection: $viewModel.model) {
                        ForEach(viewModel.availableModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // ─── モデル編集（追加＋削除）────────────
                Section(header: Text("Edit Models")) {
                    // 新規モデル追加用
                    HStack {
                        TextField("New model", text: $newModel)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Add") {
                            let m = newModel.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !m.isEmpty else { return }
                            viewModel.availableModels.append(m)
                            newModel = ""
                        }
                        .disabled(newModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // 既存モデル一覧＋削除ボタン
                    List {
                        ForEach(viewModel.availableModels, id: \.self) { m in
                            HStack {
                                Text(m)
                                Spacer()
                                Button {
                                    if let idx = viewModel.availableModels.firstIndex(of: m) {
                                        viewModel.availableModels.remove(at: idx)
                                        // 選択モデルが消えたら先頭にリセット
                                        if viewModel.model == m {
                                            viewModel.model = viewModel.availableModels.first ?? ""
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .help("Delete this model")
                            }
                        }
                    }
                    .frame(height: 150)
                }

                // ─── 完了ボタン ─────────────────────
                Section {
                    Button("Done") {
                        presentation.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentation.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 450)
    }
}

// MARK: - Swap languages helper
extension TranslationViewModel {
    func swapLanguages() {
        (inputLanguage, outputLanguage) = (outputLanguage, inputLanguage)
        translate()
    }
}
