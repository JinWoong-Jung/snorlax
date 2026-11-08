import Foundation
import Combine

struct ReportDocument: Identifiable {
    let id = UUID()
    let url: URL
    let content: ReportContent
    let generatedAt: Date
    let options: ReportExportOptions
    let report: ExportReport
}

@MainActor
final class ReportExportStore: ObservableObject {
    @Published private(set) var document: ReportDocument?
    private let generate: (ExportReport) throws -> URL
    init(generate: @escaping (ExportReport) throws -> URL) { self.generate = generate }

    @discardableResult
    func prepare(_ summary: ReportSummary, options: ReportExportOptions? = nil) throws -> ReportDocument {
        document = nil
        let selection = options ?? ReportExportOptions(summary: summary)
        let report = try summary.export(options: selection)
        let item = ReportDocument(url: try generate(report), content: summary.content, generatedAt: summary.generatedAt, options: selection, report: report)
        document = item
        return item
    }
    func reset() { document = nil }
    func synchronize(with content: ReportContent) {
        if document?.content != content { reset() }
    }
    /// This is the sole route from a prepared document to the system share sheet.
    func authorizeSharing(documentID: UUID, currentContent: ReportContent, consent: Bool) throws -> URL {
        guard consent else { throw ReportExportError.consentRequired }
        guard let document, document.id == documentID, document.content == currentContent else {
            reset()
            throw ReportExportError.outdated
        }
        return document.url
    }
}
