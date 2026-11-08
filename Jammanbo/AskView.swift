import SwiftUI

struct AskView: View {
    @EnvironmentObject private var sleepStore: SleepStore
    @EnvironmentObject private var checkInStore: CheckInStore
    @State private var question = ""
    @State private var answer: AnswerCard?
    @FocusState private var questionFieldFocused: Bool

    private var summary: ReportSummary { ReportSummary(nights: sleepStore.nights, checkIns: checkInStore.records, source: sleepStore.sourceLabel) }

    private let suggestions = ["최근 평균 수면은?", "깊은 잠은 얼마나 잤어?", "카페인과 수면을 비교해줘", "운동한 날 수면이 달랐나?", "스트레스 높았던 날은?", "어떤 기준으로 비교해?"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("내 기록에 질문")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("답변에는 사용한 날짜와 기록을 함께 표시해요.")
                            .font(.subheadline)
                            .foregroundStyle(JammanboPalette.muted)
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("예: 최근 평균 수면은?", text: $question, axis: .vertical)
                                .lineLimit(1...3)
                                .focused($questionFieldFocused)
                                .submitLabel(.search)
                                .onSubmit {
                                    questionFieldFocused = false
                                    ask()
                                }
                                .padding(13)
                                .background(JammanboPalette.raised, in: RoundedRectangle(cornerRadius: 15))
                            Button {
                                questionFieldFocused = false
                                ask()
                            } label: {
                                Label("기록에서 답 찾기", systemImage: "sparkle.magnifyingglass")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .foregroundStyle(JammanboPalette.background)
                                    .background(JammanboPalette.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("이렇게 물어볼 수 있어요")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JammanboPalette.muted)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                question = suggestion
                                questionFieldFocused = false
                                ask()
                            } label: {
                                HStack {
                                    Text(suggestion)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(14)
                                .background(JammanboPalette.surface, in: RoundedRectangle(cornerRadius: 15))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let answer {
                        SoftCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("기록 요약", systemImage: "quote.bubble.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(JammanboPalette.accent)
                                Text(answer.text)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Divider().overlay(.white.opacity(0.1))
                                Text("근거 · \(answer.evidence)")
                                    .font(.caption)
                                    .foregroundStyle(JammanboPalette.muted)
                            }
                        }
                    }

                    Text("운동·커피·긴장 등 다른 표현으로도 질문할 수 있어요. 지원 항목을 기기 안의 규칙으로 해석합니다.")
                        .font(.caption).foregroundStyle(JammanboPalette.muted)
                    DisclosureGroup("비교 계산 기준") {
                        Text(AnalysisService.comparisonPolicy).font(.caption).foregroundStyle(JammanboPalette.muted)
                    }
                    Text("잠만보는 기록을 요약하며 수면 상태를 진단하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(JammanboPalette.muted)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .onChange(of: summary.content) { _, _ in if answer != nil { ask() } }
            .scrollDismissesKeyboard(.interactively)
            .background(JammanboPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        questionFieldFocused = false
                    }
                }
            }
        }
    }

    private func ask() {
        answer = AnalysisService.answer(question: question, summary: summary)
    }
}
