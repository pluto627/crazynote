import SwiftUI
import Speech

// 启动页面视图，显示3秒后进入主界面
struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        VStack {
            if isActive {
                MainView() // 显示主视图
            } else {
                Image("Homepage") // 显示导入的图片
                    .resizable()
                    .scaledToFill() // 图片填充模式
                    .edgesIgnoringSafeArea(.all) // 让图片覆盖整个屏幕
            }
        }
        .onAppear {
            // 在3秒后切换到主视图
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

// 主视图，显示之前的界面内容，但使用透明背景
struct MainView: View {
    @StateObject private var audioPlayerManager = AudioPlayerManager() // 创建 AudioPlayerManager 实例
    @StateObject private var recorderManager = AudioRecorderManager() // 创建 AudioRecorderManager 实例
    @State private var showingRecordingView = false

    var body: some View {
        ZStack {
            Color.clear // 主页面背景设为透明
            
            VStack {
                TabView {
                    // 主界面显示音频文件列表
                    ContentView(audioPlayerManager: audioPlayerManager)
                        .tabItem {
                            Image(systemName: "newspaper.fill")
                            Text("主界面")
                        }

                    // 录音页面
                    Button(action: {
                        showingRecordingView = true
                    }) {
                        Text("录音页面")
                    }
                    .tabItem {
                        Image(systemName: "mic.fill")
                        Text("录音")
                    }
                    .sheet(isPresented: $showingRecordingView) {
                        RecordingView(recorderManager: recorderManager, isPresented: $showingRecordingView) { newRecording in
                            audioPlayerManager.audioFiles.insert(newRecording, at: 0)
                        }
                    }

                    // YouTube搜索页面
                    YouTubeSearchView()
                        .tabItem {
                            Image(systemName: "tv")
                            Text("YouTube")
                        }

                    // OpenAI 搜索页面
                    OpenAIView()
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text("搜索")
                        }
                }
                .background(Color.white) // 保持TabView背景为白色
                .cornerRadius(10) // 可选：为内容添加圆角
            }
            .padding()
        }
    }
}

struct ContentView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager  // 观察 AudioPlayerManager
    @State private var selectedFiles: Set<URL> = []  // 用于存储选中的文件 URL
    @State private var isEditing = false  // 控制是否处于选择模式

    var body: some View {
        NavigationView {
            List {
                ForEach(audioPlayerManager.audioFiles, id: \.self) { file in
                    VStack(alignment: .leading) {
                        HStack {
                            if isEditing {
                                Image(systemName: selectedFiles.contains(file) ? "checkmark.circle.fill" : "circle")
                                    .onTapGesture {
                                        if selectedFiles.contains(file) {
                                            selectedFiles.remove(file)
                                        } else {
                                            selectedFiles.insert(file)
                                        }
                                    }
                            }
                            NavigationLink(destination: DetailView(audioPlayerManager: audioPlayerManager, file: file, summaryText: .constant(audioPlayerManager.getSummary(for: file)), selectedText: .constant(audioPlayerManager.getTranscript(for: file)))) {
                                Text(audioPlayerManager.getTitle(for: file))
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                        }

                        // 添加录音转文本的前15个字，淡灰色显示
                        Text(audioPlayerManager.getTranscript(for: file).prefix(15) + "...")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .lineLimit(1) // 可选：如果希望限制在一行内显示
                    }
                }
            }
            .navigationTitle("疯狂笔记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button(action: {
                            deleteSelectedFiles()
                        }) {
                            Text("确认")
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                isEditing.toggle()
                                selectedFiles.removeAll()
                            }
                        }) {
                            Text("删去")
                        }
                    }
                }
            }
        }
    }

    private func deleteSelectedFiles() {
        for file in selectedFiles {
            audioPlayerManager.deleteFile(file)  // 调用 audioPlayerManager 的 deleteFile 方法
        }
        selectedFiles.removeAll()  // 清空选中列表
        withAnimation {
            isEditing.toggle()  // 退出选择模式
        }
    }
}

import SwiftUI
import UIKit // 导入 UIKit 以使用 UIImpactFeedbackGenerator

struct DetailView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    var file: URL // Audio file URL
    @Binding var summaryText: String
    @Binding var selectedText: String
    @State private var isPlaying = false // Toggle for play/pause state
    @State private var progress: Double = 0.0 // Progress of audio playback
    @State private var currentTime: TimeInterval = 0.0 // Current time of the audio
    @State private var duration: TimeInterval = 0.0 // Duration of the audio

    var body: some View {
        VStack {
            // Display summary text
            Text(summaryText)
                .font(.title)
                .padding()

            // Display detailed text
            ScrollView {
                Text(selectedText)
                    .padding()
            }

            Spacer()

            VStack {
                // Time Labels and Progress Bar
                HStack {
                    // Current time on the left
                    Text(timeFormatted(currentTime))
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    // Total duration on the right
                    Text(timeFormatted(duration))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)

                // Add the linear progress bar above the play/pause button
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 20) // Space between progress bar and the button

                ZStack {
                    // Background Circle for the Button
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.yellow.opacity(0.6), radius: 10)

                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium) // 创建震动反馈生成器
                        impactFeedback.impactOccurred() // 触发震动反馈

                        if isPlaying {
                            audioPlayerManager.stopPlaying() // Stop audio playback
                        } else {
                            audioPlayerManager.playAudio(from: file) // Start audio playback
                            self.startProgressTracking() // Start tracking progress
                        }
                        isPlaying.toggle() // Toggle play/pause state
                    }) {
                        Image(isPlaying ? "Stop" : "Play") // Use custom images "Stop" and "Play"
                            .resizable()
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.bottom, 50) // Move the button down
            }
            .padding(.bottom, 50) // Adjust this padding to move the button and progress bar further down if needed

            Spacer()
        }
        .onAppear {
            self.resetProgress() // Reset progress when the view appears
            self.duration = audioPlayerManager.duration // Set the total duration when view appears
        }
        .onDisappear {
            self.audioPlayerManager.stopPlaying() // Ensure audio stops when view disappears
        }
        .background(Color.clear) // Ensure the background is transparent
        .navigationBarTitle("Details", displayMode: .inline) // Set navigation bar title
    }

    // Start tracking audio progress
    private func startProgressTracking() {
        let duration = audioPlayerManager.duration
        self.duration = duration // Set the total duration
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let currentTime = self.audioPlayerManager.currentTime
            self.progress = currentTime / duration
            self.currentTime = currentTime // Update the current time
            
            if !self.isPlaying || self.progress >= 1.0 {
                timer.invalidate()
            }
        }
    }

    // Reset progress when view appears
    private func resetProgress() {
        self.progress = 0.0
        self.currentTime = 0.0
    }

    // Helper function to format time interval into MM:SS format
    private func timeFormatted(_ totalSeconds: TimeInterval) -> String {
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    SplashView() // 启动页面预览
}
