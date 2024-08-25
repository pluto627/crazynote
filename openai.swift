import Foundation
import SwiftUI

class OpenAIViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var responseText: String = ""
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var isSummarizationRequested: Bool = false
    
    // 添加 `history` 属性来存储对话历史
    @Published var history: [String] = []

    private let apiKey = "sk-m4JM1xiRTjGhxqXoDJLKGm7M3UuInao7biyq8vGdXuPLxQZd" // 请替换为你的实际 API 密钥
    private let baseURL = "https://api.fe8.cn/v1"

    func fetchData() async {
        guard !prompt.isEmpty else {
            errorMessage = "提示不能为空"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let formattedPrompt = formatPrompt(prompt: prompt, isSummarization: isSummarizationRequested)

        do {
            let result = try await fetchOpenAIResponse(prompt: formattedPrompt)
            responseText = result
            
            // 将提示和响应存储到历史记录中
            history.append("提示: \(prompt)\n响应: \(result)")
            
            // 发送概括请求
            let summaryPrompt = "帮我讲以上的文本概括为一句话: \(result)"
            let summaryResult = try await fetchOpenAIResponse(prompt: summaryPrompt)
            
            let fileName = summaryResult.trimmingCharacters(in: .whitespacesAndNewlines)
            print("文件名: \(fileName)")

            // 保存文件
            saveFile(named: fileName, content: result)

        } catch {
            errorMessage = "请求失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    private func formatPrompt(prompt: String, isSummarization: Bool) -> String {
        if isSummarization {
            return "概括: \(prompt)"
        } else {
            return prompt
        }
    }

    private func fetchOpenAIResponse(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Error Code: \(httpResponse.statusCode)")
            }
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        return content
    }

    private func saveFile(named fileName: String, content: String) {
        // 实现文件保存逻辑
        print("Saving file with name: \(fileName) and content: \(content)")
        // 示例代码，仅作展示，需根据需求实际实现
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sanitizedFileName = fileName.replacingOccurrences(of: "/", with: "_") // 处理文件名中的非法字符
        let fileURL = documentsDirectory.appendingPathComponent("\(sanitizedFileName).txt")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("File saved at \(fileURL.path)")
        } catch {
            print("Error saving file: \(error.localizedDescription)")
        }
    }
}
