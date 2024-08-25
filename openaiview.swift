import SwiftUI

struct OpenAIView: View {
    @StateObject private var viewModel = OpenAIViewModel()
    @State private var showMenu = false // 用于控制菜单的显示和隐藏
    @State private var selectedQuestion: String? = nil // 保存选中的问题

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                showMenu.toggle() // 点击按钮后显示或隐藏菜单
                            }
                        }) {
                            Image(systemName: "line.horizontal.3") // 三个横线的图标
                                .foregroundColor(.blue)
                                .imageScale(.large)
                                .padding()
                        }
                        .position(x: 20, y: 20) // 将按钮放置到最左上角
                        Spacer()
                    }

                    Spacer()

                    HStack {
                        TextField("输入你的提示", text: $viewModel.prompt)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding([.leading, .bottom])

                        Button(action: {
                            Task {
                                // 如果这是第一次提问，将提问内容保存到历史记录中
                                if viewModel.history.isEmpty {
                                    viewModel.history.append(viewModel.prompt)
                                }
                                await viewModel.fetchData()
                            }
                        }) {
                            Text("提交")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding([.trailing, .bottom])
                    }

                    if viewModel.isLoading {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }

                    if !viewModel.responseText.isEmpty {
                        Text("响应:")
                            .font(.headline)
                            .padding(.top)

                        ScrollView {
                            Text(viewModel.responseText)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .padding()
                        }
                        .frame(maxHeight: 200) // 设置滚动区域的最大高度，可以根据需要调整
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text("错误: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
                .navigationTitle("OpenAI 提示")

                // 菜单滑动视图
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        if showMenu {
                            Color.black.opacity(0.4)
                                .edgesIgnoringSafeArea(.all)
                                .onTapGesture {
                                    withAnimation {
                                        showMenu = false // 点击菜单外部区域时隐藏菜单
                                    }
                                }
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                if let firstQuestion = viewModel.history.first {
                                    Button(action: {
                                        withAnimation {
                                            selectedQuestion = firstQuestion
                                            showMenu = false // 隐藏菜单
                                        }
                                    }) {
                                        Text(firstQuestion)
                                            .padding()
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(8)
                                            .padding(.horizontal)
                                    }
                                }

                                Spacer()
                            }
                            .frame(width: geometry.size.width * 0.6) // 菜单宽度为屏幕宽度的60%
                            .background(Color.white)
                            .offset(x: showMenu ? 0 : -geometry.size.width * 0.6) // 控制菜单的滑动效果

                            Spacer()
                        }
                    }
                    .animation(.default, value: showMenu)
                }
            }
            .onChange(of: selectedQuestion) { newValue in
                if let question = newValue {
                    viewModel.prompt = question
                    Task {
                        await viewModel.fetchData() // 再次请求显示选中的问题的详细内容
                    }
                }
            }
        }
    }
}

struct OpenAIView_Previews: PreviewProvider {
    static var previews: some View {
        OpenAIView()
    }
}
