import SwiftUI
import PDFKit

struct PDFPreviewSheet: View {
    let document: ReportDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("생성 \(document.generatedAt.formatted(.dateTime.month().day().hour().minute())) · \(document.content.source)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                PDFPageView(url: document.url)
            }
            .navigationTitle("수면 요약 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("완료") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { ShareLink(item: document.url) { Label("공유", systemImage: "square.and.arrow.up") } }
            }
        }
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
