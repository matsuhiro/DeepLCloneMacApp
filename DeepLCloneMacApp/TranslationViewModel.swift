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
    
    // ユーザーが追加可能なモデル一覧（永続化）
    @Published var availableModels: [String] =
        UserDefaults.standard.stringArray(forKey: "availableModels")
        ?? ["gpt-3.5-turbo","gpt-4","gpt-4o-mini"]

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 言語設定変更時に永続化
        $inputLanguage
            .sink { UserDefaults.standard.set($0, forKey: "inputLanguage") }
            .store(in: &cancellables)
        $outputLanguage
            .sink { UserDefaults.standard.set($0, forKey: "outputLanguage") }
            .store(in: &cancellables)

        // API設定変更時にも永続化
        $apiKey
            .sink { UserDefaults.standard.set($0, forKey: "apiKey") }
            .store(in: &cancellables)
        $apiBaseURL
            .sink { UserDefaults.standard.set($0, forKey: "apiBaseURL") }
            .store(in: &cancellables)
        $model
            .sink { UserDefaults.standard.set($0, forKey: "model") }
            .store(in: &cancellables)

        // inputText の変更を 1 秒デバウンスしてから翻訳実行
        $inputText
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.translate()
            }
            .store(in: &cancellables)
        
        $availableModels
            .sink { UserDefaults.standard.set($0, forKey: "availableModels") }
            .store(in: &cancellables)
    }

    /// 翻訳リクエストを実行
    func translate() {
        // 空白・改行のみなら翻訳せずクリア
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translatedText = ""
            return
        }

        // 入力テキストを使用
        let textToTranslate = trimmed

        // 自動検出 or 手動指定
        let detectedLang = (inputLanguage == "auto")
            ? autodetectLanguage(textToTranslate)
            : inputLanguage

        // Chat API 用メッセージ構成
        let messages: [[String:String]] = [
            ["role": "system", "content": "You are a helpful translator."],
            ["role": "user", "content":
                "Translate this text from \(detectedLang) to \(outputLanguage):\n\n\(textToTranslate)"
            ]
        ]

        // API エンドポイントの検証
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
            "messages": messages
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("🔷 [DEBUG] Request to \(url)")
        print("🔷 [DEBUG] Headers:", request.allHTTPHeaderFields ?? [:])
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
                print("🔶 [DEBUG] Response Data: \(dataStr)")
                #endif
            })
            .map(\.data)
            .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    #if DEBUG
                    if case .failure(let error) = completion {
                        print("❌ [DEBUG] Translation error:", error)
                    }
                    #endif
                },
                receiveValue: { [weak self] response in
                    self?.translatedText = response
                        .choices
                        .first?
                        .message
                        .content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? ""
                }
            )
            .store(in: &cancellables)
    }

    /// クリップボードの文字列を入力欄にセット（翻訳はデバウンスで自動実行）
    func translateClipboard() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
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

// MARK: - API レスポンスモデル
struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
