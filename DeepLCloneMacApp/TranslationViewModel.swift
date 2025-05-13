// TranslationViewModel.swift

import Foundation
import Combine
import AppKit
import NaturalLanguage

@MainActor
class TranslationViewModel: ObservableObject {
    // 入力テキストと翻訳結果
    @Published var inputText: String = ""
    @Published var translatedText: String = ""

    // 言語設定を永続化
    @Published var inputLanguage: String = UserDefaults.standard.string(forKey: "inputLanguage") ?? "auto"
    @Published var outputLanguage: String = UserDefaults.standard.string(forKey: "outputLanguage") ?? "en"

    // APIキー／URL／モデル名も UserDefaults 経由で永続化
    @Published var apiKey: String = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    @Published var apiBaseURL: String = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://api.openai.com/v1/chat/completions"
    @Published var model: String = UserDefaults.standard.string(forKey: "model") ?? "gpt-3.5-turbo"
    @Published var availableModels: [String] =
        UserDefaults.standard.stringArray(forKey: "availableModels")
        ?? ["gpt-3.5-turbo", "gpt-4", "gpt-4o-mini"]

    /// 通信中フラグ
    @Published var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    /// デバウンス間隔（秒）
    private let debounceInterval: TimeInterval = 0.3

    init() {
        // UserDefaults 永続化
        [
            ($inputLanguage, "inputLanguage"),
            ($outputLanguage, "outputLanguage"),
            ($apiKey, "apiKey"),
            ($apiBaseURL, "apiBaseURL"),
            ($model, "model")
        ].forEach { publisher, key in
            publisher
                .sink { UserDefaults.standard.set($0, forKey: key) }
                .store(in: &cancellables)
        }
        // availableModels 永続化
        $availableModels
            .sink { UserDefaults.standard.set($0, forKey: "availableModels") }
            .store(in: &cancellables)

        // 入力テキストの変更をデバウンスして翻訳実行
        $inputText
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.translate() }
            .store(in: &cancellables)

        // 言語／モデル変更をデバウンスして再翻訳
        [$inputLanguage, $outputLanguage, $model].forEach { publisher in
            publisher
                .dropFirst()
                .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
                .sink { [weak self] _ in self?.translate() }
                .store(in: &cancellables)
        }
    }

    /// 翻訳リクエストを実行
    func translate() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translatedText = ""
            return
        }
        let textToTranslate = trimmed
        let detectedLang = (inputLanguage == "auto")
            ? autodetectLanguage(textToTranslate)
            : inputLanguage

        // リクエスト構築
        guard let url = URL(string: apiBaseURL) else {
            print("❌ Invalid API Base URL: \(apiBaseURL)")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String:Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a helpful translator."],
                ["role": "user",   "content": "Translate this text from \(detectedLang) to \(outputLanguage):\n\n\(textToTranslate)"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // 通信開始フラグ
        DispatchQueue.main.async { self.isLoading = true }

        #if DEBUG
        print("🔷 [DEBUG] Request to \(url)")
        if let data = request.httpBody, let bodyStr = String(data: data, encoding: .utf8) {
            print("🔷 [DEBUG] Body:", bodyStr)
        }
        #endif

        URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { output in
                #if DEBUG
                if let resp = output.response as? HTTPURLResponse {
                    print("🔶 [DEBUG] Status: \(resp.statusCode)")
                }
                let dataStr = String(data: output.data, encoding: .utf8) ?? "<non-utf8>"
                print("🔶 [DEBUG] Response Data:", dataStr)
                #endif
            })
            .map(\.data)
            .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    #if DEBUG
                    if case .failure(let error) = completion {
                        print("❌ [DEBUG] Error:", error)
                    }
                    #endif
                },
                receiveValue: { [weak self] response in
                    self?.translatedText = response
                        .choices.first?
                        .message.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? ""
                }
            )
            .store(in: &cancellables)
    }

    /// クリップボード翻訳（入力セットのみ）
    func translateClipboard() {
        if let text = NSPasteboard.general.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            inputText = text
        }
    }

    /// 自動言語検出
    private func autodetectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }
}

// API レスポンスモデル
struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let role: String; let content: String }
        let message: Message
    }
    let choices: [Choice]
}
