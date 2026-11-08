import SwiftUI

struct CheckInHistoryView: View {
    @EnvironmentObject private var store: CheckInStore

    var body: some View {
        List {
            Section {
                if store.records.isEmpty {
                    ContentUnavailableView("아직 체크인이 없어요", systemImage: "checkmark.circle", description: Text("체크인 화면에서 오늘의 기분을 저장해 주세요."))
                }
                ForEach(store.records) { record in
                    NavigationLink { CheckInDetailView(id: record.id) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(record.mood) · 스트레스 \(record.stress)")
                            Text(record.date.formatted(.dateTime.month().day().hour().minute()) + " · " + record.source)
                                .font(.caption).foregroundStyle(.secondary)
                            Text(record.exerciseLabel).font(.caption).foregroundStyle(.secondary)
                            Text(record.caffeine ? "오후 카페인 있음" : "오후 카페인 없음")
                                .font(.caption).foregroundStyle(record.caffeine ? JammanboPalette.coral : JammanboPalette.muted)
                        }
                    }
                    .listRowBackground(JammanboPalette.surface)
                }
            } footer: {
                Text("기록 시각이 최근인 30건을 보관합니다. 항목을 눌러 이 iPhone의 기록을 수정하거나 삭제할 수 있어요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(JammanboPalette.background)
        .navigationTitle("체크인 전체 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct CheckInDetailView: View {
    let id: UUID
    @EnvironmentObject private var store: CheckInStore
    @Environment(\.dismiss) private var dismiss
    @State private var mood = "괜찮아요"
    @State private var stress = "보통"
    @State private var caffeine = false
    @State private var exercise: Bool? = nil
    @State private var confirmDelete = false
    private var record: CheckIn? { store.records.first { $0.id == id } }

    var body: some View {
        Form {
            if let record {
                Section("입력 정보") {
                    LabeledContent("기록 시각", value: record.date.formatted(.dateTime.month().day().hour().minute()))
                    LabeledContent("입력 위치", value: record.source)
                }
                Section("체크인 수정") {
                    Picker("기분", selection: $mood) {
                        ForEach(["개운해요", "괜찮아요", "피곤해요"], id: \.self) { Text($0) }
                        if !["개운해요", "괜찮아요", "피곤해요"].contains(mood) { Text(mood).tag(mood) }
                    }
                    Picker("스트레스", selection: $stress) {
                        ForEach(["낮음", "보통", "높음"], id: \.self) { Text($0) }
                    }
                    Toggle("오후 카페인", isOn: $caffeine)
                    Picker("전날 운동", selection: $exercise) {
                        Text("미기록").tag(Optional<Bool>.none)
                        Text("있음").tag(Optional(true))
                        Text("없음").tag(Optional(false))
                    }
                    Button("수정 내용 저장") {
                        store.update(id: id, mood: mood, stress: stress, caffeine: caffeine, exercise: exercise)
                        dismiss()
                    }
                }
                Section {
                    Button("이 체크인 삭제", role: .destructive) { confirmDelete = true }
                } footer: { Text("이 iPhone에 보관한 기록만 변경합니다. 삭제한 기록은 되돌릴 수 없습니다.") }
            } else {
                Text("이 기록은 삭제되었거나 보관 범위를 벗어났어요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(JammanboPalette.background)
        .navigationTitle("체크인 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            if let record { mood = record.mood; stress = record.stress; caffeine = record.caffeine; exercise = record.exercise }
        }
        .confirmationDialog("이 체크인을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { store.remove(id: id); dismiss() }
            Button("취소", role: .cancel) {}
        }
    }
}
