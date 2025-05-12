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

    private var cancellables = Set<AnyCancellable>()

    /// 環境変数から取得した API キー
    private var apiKey: String {
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
            fatalError("Missing OPENAI_API_KEY in environment")
        }
        return key
    }

    /// 環境変数から取得したエンドポイント URL
    private var endpoint: URL {
        guard let urlString = ProcessInfo.processInfo.environment["OPENAI_API_BASE_URL"],
              let url = URL(string: urlString) else {
            fatalError("Missing or invalid OPENAI_API_BASE_URL in environment")
        }
        return url
    }

    init() {
        // 言語設定変更時に永続化
        $inputLanguage
            .sink { UserDefaults.standard.set($0, forKey: "inputLanguage") }
            .store(in: &cancellables)
        $outputLanguage
            .sink { UserDefaults.standard.set($0, forKey: "outputLanguage") }
            .store(in: &cancellables)

        // inputText の変更を 1 秒デバウンスしてから翻訳実行
        $inputText
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.translate()
            }
            .store(in: &cancellables)
    }

    /// 翻訳リクエストを実行
    func translate() {
        let detectedLang = (inputLanguage == "auto")
            ? autodetectLanguage(inputText)
            : inputLanguage

        let messages: [[String:String]] = [
            ["role": "system", "content": "You are a helpful translator."],
            ["role": "user", "content":
                "Translate this text from \(detectedLang) to \(outputLanguage):\n\n\(inputText)"
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String:Any] = [
            "model": "gpt-4.1-nano",
            "messages": messages
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        if let data = request.httpBody, let bodyStr = String(data: data, encoding: .utf8) {
            print("🔷 [DEBUG] Request URL: \(request.url?.absoluteString ?? "")")
            print("🔷 [DEBUG] Request Body: \(bodyStr)")
        }
        #endif

        URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { output in
                #if DEBUG
                if let resp = output.response as? HTTPURLResponse {
                    print("🔶 [DEBUG] Response Status: \(resp.statusCode)")
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

    /// クリップボードの文字列を翻訳
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
