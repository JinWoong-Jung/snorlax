import Foundation
import Combine

struct ReportDocument: Identifiable {
    let id = UUID()
    let url: URL
    let content: ReportContent
    let generatedAt: Date
}

@MainActor
final class ReportExportStore: ObservableObject {
    @Published private(set) var document: ReportDocument?
    private let generate: (ReportSummary) throws -> URL

    init(generate: @escaping (ReportSummary) throws -> URL) { self.generate = generate }

    @discardableResult
    func prepare(_ summary: ReportSummary) throws -> ReportDocument {
        document = nil
        let item = ReportDocument(url: try generate(summary), content: summary.content, generatedAt: summary.generatedAt)
        document = item
        return item
    }

    func synchronize(with content: ReportContent) {
        if document?.content != content { document = nil }
    }
}
