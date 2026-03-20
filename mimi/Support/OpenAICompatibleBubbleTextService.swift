import Foundation

final class OpenAICompatibleBubbleTextService: ExpressionTextProvider {
    struct Configuration {
        let baseURL: URL
        let apiKey: String
        let model: String
        let timeout: TimeInterval

        static func fromEnvironment(processInfo: ProcessInfo = .processInfo) -> Configuration? {
            let environment = processInfo.environment

            guard
                let baseURLString = environment["MIMI_LLM_API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                let baseURL = URL(string: baseURLString),
                let apiKey = environment["MIMI_LLM_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                let model = environment["MIMI_LLM_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey.isEmpty == false,
                model.isEmpty == false
            else {
                return nil
            }

            let timeoutMilliseconds = Double(environment["MIMI_LLM_TIMEOUT_MS"] ?? "") ?? 1200
            return Configuration(
                baseURL: baseURL,
                apiKey: apiKey,
                model: model,
                timeout: max(0.4, timeoutMilliseconds / 1000)
            )
        }

        var endpointURL: URL {
            let path = baseURL.path.lowercased()
            if path.hasSuffix("/chat/completions") {
                return baseURL
            }
            if path.hasSuffix("/v1") {
                return baseURL.appendingPathComponent("chat/completions")
            }
            return baseURL.appendingPathComponent("v1/chat/completions")
        }
    }

    private struct ChatCompletionsRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatCompletionsResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message
        }

        let choices: [Choice]
    }

    private let configuration: Configuration
    private let session: URLSession

    init(configuration: Configuration) {
        self.configuration = configuration

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout
        self.session = URLSession(configuration: sessionConfiguration)
    }

    static func fromEnvironment(processInfo: ProcessInfo = .processInfo) -> OpenAICompatibleBubbleTextService? {
        guard let configuration = Configuration.fromEnvironment(processInfo: processInfo) else {
            return nil
        }
        return OpenAICompatibleBubbleTextService(configuration: configuration)
    }

    func generateText(for request: BubbleTextRequest, completion: @escaping (String?) -> Void) {
        var urlRequest = URLRequest(url: configuration.endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatCompletionsRequest(
            model: configuration.model,
            messages: [
                .init(
                    role: "system",
                    content: """
                    你是桌面宠物 mimi 的表达层。
                    只输出一句简短中文短语。
                    不要解释，不要引号，不要换行。
                    长度不超过\(request.maxLength)个字符。
                    """
                ),
                .init(role: "user", content: userPrompt(for: request))
            ],
            temperature: 0.8,
            max_tokens: 24
        )

        do {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        } catch {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        session.dataTask(with: urlRequest) { data, _, error in
            guard error == nil, let data else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            let decoded = try? JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
            let content = decoded?.choices.first?.message.content

            DispatchQueue.main.async {
                completion(content)
            }
        }.resume()
    }

    private func userPrompt(for request: BubbleTextRequest) -> String {
        let candidates = request.candidates.joined(separator: " / ")
        return """
        当前预设: \(request.presetID)
        当前类别: \(request.category.llmLabel)
        当前气泡风格: \(request.style.llmLabel)
        候选短句: \(candidates)
        当前本地fallback: \(request.fallbackText)
        生成一句更贴合状态、但风格接近候选集的短句。
        """
    }
}
