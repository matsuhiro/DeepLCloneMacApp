import Foundation
import Combine
import AppKit
import NaturalLanguage


class TranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var translatedText: String = ""
    @Published var inputLanguage: String = UserDefaults.standard.string(forKey: "inputLanguage") ?? "auto"
    @Published var outputLanguage: String = UserDefaults.standard.string(forKey: "outputLanguage") ?? "en"

    private var cancellables = Set<AnyCancellable>()
    private let apiKey = "YOUR_API_KEY"
    private let endpoint = URL(string: "https://api.yourservice.com/v1/chat/completions")! // OpenAI-compatible endpoint

    init() {
        // Persist changes
        $inputLanguage.sink { UserDefaults.standard.set($0, forKey: "inputLanguage") }
            .store(in: &cancellables)
        $outputLanguage.sink { UserDefaults.standard.set($0, forKey: "outputLanguage") }
            .store(in: &cancellables)
    }

    func translate() {
        let detectedLang = (inputLanguage == "auto") ? autodetectLanguage(inputText) : inputLanguage
        let messages = [
            ["role": "system", "content": "You are a helpful translator."],
            ["role": "user", "content": "Translate this text from \(detectedLang) to \(outputLanguage):\n\n\(inputText)"]
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": "gpt-3.5-turbo", "messages": messages])

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                self?.translatedText = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            })
            .store(in: &cancellables)
    }

    func translateClipboard() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            inputText = text
            translate()
        }
    }

    private func autodetectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }
}

// MARK: - ChatCompletionResponse model
struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable { let role: String; let content: String }
        let message: Message
    }
    let choices: [Choice]
}
