import SwiftUI
import WebKit
import Foundation
import Combine

struct YouTubeSearchView: View {
    @ObservedObject var viewModel = VideoSearchViewModel()
    @State private var searchText = ""

    var body: some View {
        VStack {
            HStack {
                TextField("Search YouTube", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("发送") {
                    viewModel.searchYouTube(query: searchText)
                }
                .padding(.leading, 10)
            }
            .padding()

            if viewModel.isLoading {
                ProgressView()
            } else if let url = viewModel.videoURL {
                WebView(url: url)
            } else {
                Text("Search and play YouTube videos")
            }
        }
        .navigationTitle("YouTube Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

class VideoSearchViewModel: ObservableObject {
    @Published var videoURL: URL? = nil
    @Published var isLoading = false

    func searchYouTube(query: String) {
        isLoading = true
        let apiKey = "AIzaSyDDwB3ZsBC4G108thueljBCjpxmOtipg5U"
        let queryComponents = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=\(queryComponents)&key=\(apiKey)"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else { return }
                if let videoId = self.parseVideoId(data: data) {
                    self.videoURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")
                }
            }
        }.resume()
    }

    private func parseVideoId(data: Data) -> String? {
        do {
            if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = jsonResult["items"] as? [[String: Any]],
               let firstItem = items.first,
               let idDict = firstItem["id"] as? [String: Any],
               let videoId = idDict["videoId"] as? String {
                return videoId
            }
        } catch {
            print("JSON Error: \(error)")
        }
        return nil
    }
}
struct YouTubeSearchView_Previews: PreviewProvider {
    static var previews: some View {
        YouTubeSearchView()
    }
}
