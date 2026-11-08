import SwiftUI
import PDFKit

struct ReportExportFlow: View {
    @EnvironmentObject private var sleepStore: SleepStore
    @EnvironmentObject private var checkInStore: CheckInStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exports = ReportExportStore(generate: ReportPDFGenerator.create)
    @State private var options: ReportExportOptions?
    @State private var preview: ReportDocument?
    @State private var error: String?
    private var summary: ReportSummary { ReportSummary(nights: sleepStore.nights, checkIns: checkInStore.records, source: sleepStore.sourceLabel) }
    private var availableDates: [Date] {
        Set((summary.nights.map(\.date) + summary.checkIns.map(\.date)).map { Calendar.current.startOfDay(for: $0) }).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("날짜와 항목을 고르면 이 기기에서 PDF를 만듭니다. 내용을 확인하고 마지막에 동의해야 공유 대상을 선택할 수 있어요. 자동으로 전송하지 않습니다.")
                }
                Section("포함할 날짜 · 최근 7일") {
                    ForEach(availableDates, id: \.self) { date in
                        Toggle(date.formatted(.dateTime.month().day().weekday()), isOn: dateBinding(date))
                    }
                    if availableDates.isEmpty { Text("내보낼 기록이 없습니다.") }
                }
                Section("수면 항목") {
                    Toggle("총 수면시간·평균", isOn: fieldBinding(\.includeSleepTotals))
                    Toggle("수면 단계", isOn: fieldBinding(\.includeSleepStages))
                }
                Section {
                    ForEach(CheckInExportField.allCases, id: \.self) { field in
                        Toggle(field.label, isOn: checkInBinding(field))
                    }
                } header: { Text("체크인 항목 · 기본은 모두 제외") }
                  footer: { Text("선택하지 않은 체크인 값과 기록 개수는 PDF에 넣지 않습니다.") }
                Section("선택 내용 확인") {
                    Text("\(options?.dates.count ?? 0)개 날짜 · \(options?.labels.joined(separator: ", ") ?? "")")
                    Button("선택한 데이터로 PDF 미리보기") {
                        guard let options else { return }
                        do { preview = try exports.prepare(summary, options: options); error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                    .disabled(options?.hasFields != true || options?.dates.isEmpty != false)
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("공유할 데이터 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
        .onAppear { if options == nil { options = ReportExportOptions(summary: summary) } }
        .onChange(of: options) { _, _ in exports.reset(); preview = nil; error = nil }
        .onChange(of: summary.content) { _, content in
            exports.synchronize(with: content); preview = nil
            if var selected = options {
                selected.dates.formIntersection(Set(availableDates))
                options = selected
            }
            error = "기록이 변경됐어요. 선택 내용을 확인하고 새 PDF를 만들어 주세요."
        }
        .sheet(item: $preview) { document in
            PDFPreviewSheet(document: document, exports: exports, currentContent: { summary.content })
        }
    }
    private func fieldBinding(_ path: WritableKeyPath<ReportExportOptions, Bool>) -> Binding<Bool> {
        Binding(get: { options?[keyPath: path] ?? false }, set: { value in
            guard var selected = options else { return }; selected[keyPath: path] = value; options = selected
        })
    }
    private func dateBinding(_ date: Date) -> Binding<Bool> {
        Binding(get: { options?.dates.contains(date) == true }, set: { value in
            guard var selected = options else { return }
            if value { selected.dates.insert(date) } else { selected.dates.remove(date) }
            options = selected
        })
    }
    private func checkInBinding(_ field: CheckInExportField) -> Binding<Bool> {
        Binding(get: { options?.checkInFields.contains(field) == true }, set: { value in
            guard var selected = options else { return }
            if value { selected.checkInFields.insert(field) } else { selected.checkInFields.remove(field) }
            options = selected
        })
    }
}

struct PDFPreviewSheet: View {
    let document: ReportDocument
    @ObservedObject var exports: ReportExportStore
    let currentContent: () -> ReportContent
    @Environment(\.dismiss) private var dismiss
    @State private var consent = false
    @State private var sharing: SharePayload?
    @State private var error: String?
    private struct SharePayload: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("포함: " + document.report.selectedLabels.joined(separator: ", "))
                    .font(.caption).padding(.horizontal)
                PDFPageView(url: document.url)
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("PDF 내용을 확인했으며 선택한 데이터를 공유하는 데 동의합니다", isOn: $consent)
                        .font(.subheadline)
                    Text("다음 화면에서 앱·수신자를 직접 선택합니다. 닫기·취소하면 앱이 자동 전송하지 않습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("동의하고 공유 대상 선택") {
                        do {
                            let url = try exports.authorizeSharing(documentID: document.id, currentContent: currentContent(), consent: consent)
                            consent = false
                            sharing = SharePayload(url: url)
                        } catch { self.error = error.localizedDescription; consent = false }
                    }.buttonStyle(.borderedProminent).disabled(!consent)
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }.padding()
            }
            .navigationTitle("선택한 PDF 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("완료") { consent = false; dismiss() } } }
        }
        .sheet(item: $sharing) { PDFShareSheet(url: $0.url) }
    }
}

private struct PDFPageView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}

struct PDFShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
