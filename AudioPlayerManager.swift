import SwiftUI
import AVFoundation
import WatchConnectivity
import Speech

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate, WCSessionDelegate {
    @Published var audioFiles: [URL] = []
    @Published var isPlaying = false
    @Published var convertedText: String = ""
    @Published var summaries: [URL: String] = [:]
    @Published var titles: [URL: String] = [:]

    private var audioPlayer: AVAudioPlayer?
    private let session = WCSession.default
    private var transcripts: [URL: String] = [:]
    private let transcriptsKey = "savedTranscripts"

    override init() {
        super.init()

        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("语音识别已授权")
                case .denied, .restricted, .notDetermined:
                    print("语音识别授权失败: \(authStatus)")
                @unknown default:
                    fatalError("未知的语音识别授权状态")
                }
            }
        }

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }

        loadTranscriptions()
        loadAudioFiles()
    }

    func playAudio(from url: URL) {
        stopPlaying()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("播放音频失败: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }

    var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func loadAudioFiles() {
        let documentsDirectory = getDocumentsDirectory()

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            audioFiles = fileURLs.filter { $0.pathExtension == "m4a" }
        } catch {
            print("加载音频文件失败: \(error.localizedDescription)")
        }
    }

    func deleteFile(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
            if let index = audioFiles.firstIndex(of: file) {
                audioFiles.remove(at: index)
            }
            // Also remove the transcription from persistent storage
            transcripts[file] = nil
            saveTranscriptions()
        } catch {
            print("删除文件时出错: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let destinationURL = getDocumentsDirectory().appendingPathComponent(file.fileURL.lastPathComponent)

        do {
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)
            print("文件已接收并保存到: \(destinationURL)")
            DispatchQueue.main.async {
                self.audioFiles.append(destinationURL)
                self.convertAudioToText(audioURL: destinationURL)
            }
        } catch {
            print("保存文件时出错: \(error.localizedDescription)")
        }
    }

    private func convertAudioToText(audioURL: URL) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("未授权语音识别。")
            return
        }

        let chineseRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        let request = SFSpeechURLRecognitionRequest(url: audioURL)

        chineseRecognizer?.recognitionTask(with: request) { result, error in
            guard let result = result, error == nil else {
                print("中文语音识别失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }

            if result.isFinal {
                let recognizedText = result.bestTranscription.formattedString
                self.processRecognizedText(recognizedText, from: audioURL)
            }
        }
    }

    private func processRecognizedText(_ text: String, from audioURL: URL) {
        self.convertedText = text
        self.transcripts[audioURL] = text
        saveTranscriptions()  // Save the transcription to persistent storage
        print("识别的文本: \(text)")

        Task {
            await self.generateSummaryAndTitle(for: text, from: audioURL)
        }
    }

    private func generateSummaryAndTitle(for text: String, from audioURL: URL) async {
        let apiKey = "sk-m4JM1xiRTjGhxqXoDJLKGm7M3UuInao7biyq8vGdXuPLxQZd" // Replace with your actual OpenAI API key
        let baseURL = "https://api.fe8.cn/v1/chat/completions" // OpenAI GPT endpoint

        guard let url = URL(string: baseURL) else {
            print("无效的 URL")
            return
        }

        print("请求 URL: \(url)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formattedText = "请你帮我将以下的内容概括为5个字: \(text)"
        let requestBody: [String: Any] = [
            "model": "gpt-4", // or "gpt-4" if you are using GPT-4
            "messages": [
                [
                    "role": "user",
                    "content": formattedText
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let mimeType = httpResponse.mimeType, mimeType == "application/json" {
                    processApiResponse(data: data, audioURL: audioURL)
                } else {
                    print("收到非 JSON 响应")
                    handleHTMLResponse(data: data, audioURL: audioURL) // Pass the audioURL here
                }
            } else {
                print("请求失败，状态码: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        } catch {
            print("发送文本到服务器时出错: \(error.localizedDescription)")
        }
    }

    private func processApiResponse(data: Data, audioURL: URL) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                DispatchQueue.main.async {
                    let summary = String(content.prefix(5))
                    self.summaries[audioURL] = content
                    self.titles[audioURL] = summary
                    print("生成的摘要和标题: \(summary)")
                }
            } else {
                print("响应中缺少预期的 'choices' 或 'message' 键。")
            }
        } catch {
            print("解析响应 JSON 时出错: \(error.localizedDescription)")
        }
    }

    private func handleHTMLResponse(data: Data, audioURL: URL) {
        if let htmlString = String(data: data, encoding: .utf8) {
            print("收到 HTML 内容: \(htmlString)")

            DispatchQueue.main.async {
                self.summaries[audioURL] = "无法生成摘要 - 非预期响应"
                self.titles[audioURL] = "错误"
            }

            if htmlString.contains("Just service for AGI") {
                print("页面表明这是一个为 AGI 服务的页面。")
            }

            if let titleRange = htmlString.range(of: "<title>(.*?)</title>", options: .regularExpression) {
                let title = String(htmlString[titleRange])
                    .replacingOccurrences(of: "<title>", with: "")
                    .replacingOccurrences(of: "</title>", with: "")
                print("提取的标题: \(title)")
            }
        } else {
            print("无法将 HTML 数据转换为字符串。")
        }
    }

    private func saveTranscriptions() {
        // Convert the transcripts dictionary to a savable format
        let savedData = transcripts.reduce(into: [String: String]()) { result, item in
            result[item.key.path] = item.value
        }
        UserDefaults.standard.set(savedData, forKey: transcriptsKey)
    }

    private func loadTranscriptions() {
        if let savedData = UserDefaults.standard.dictionary(forKey: transcriptsKey) as? [String: String] {
            transcripts = savedData.reduce(into: [:]) { result, item in
                let url = URL(fileURLWithPath: item.key)
                result[url] = item.value
            }
        }
    }

    func getTranscript(for fileURL: URL) -> String {
        return transcripts[fileURL] ?? "无可用转录文本"
    }

    func getSummary(for fileURL: URL) -> String {
        return summaries[fileURL] ?? "摘要生成中..."
    }

    func getTitle(for fileURL: URL) -> String {
        return titles[fileURL] ?? "标题生成中..."
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        print("音频播放成功结束: \(flag)")
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession 激活失败，错误: \(error.localizedDescription)")
        } else {
            print("WCSession 已激活，状态: \(activationState.rawValue)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("会话已变为非活动状态")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("会话已停用")
        session.activate()
    }
}
