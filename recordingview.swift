import SwiftUI

struct RecordingView: View {
    @ObservedObject var recorderManager: AudioRecorderManager
    @Binding var isPresented: Bool
    var onSave: (URL) -> Void
    
    var body: some View {
        VStack {
            if recorderManager.isRecording {
                Text("录音中...").font(.title)
                Button(action: {
                    if let url = recorderManager.stopRecording() {
                        onSave(url)
                        isPresented = false
                    }
                }) {
                    Text("停止录音")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Button(action: {
                    recorderManager.startRecording()
                }) {
                    Text("开始录音")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(radius: 8)
        .padding()
    }
}
