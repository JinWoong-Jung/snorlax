import Foundation
import UIKit

enum ReportPDFGenerator {
    static func create(report: ExportReport) throws -> URL {
        removeExpiredReports()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Jammanbo-Sleep-Summary-\(UUID().uuidString).pdf")
        let data = renderer.pdfData { context in
            let ink = UIColor(red: 0.10, green: 0.15, blue: 0.25, alpha: 1)
            let secondary = UIColor.darkGray
            var y: CGFloat = 0
            var page = 0
            func newPage() {
                context.beginPage(); page += 1
                draw("잠만보 · 선택한 기록 요약", in: CGRect(x: 48, y: 42, width: 499, height: 32), font: .boldSystemFont(ofSize: 22), color: ink)
                draw("생성 \(report.generatedAt.formatted(.dateTime.year().month().day())) · \(page)페이지", in: CGRect(x: 48, y: 80, width: 499, height: 20), font: .systemFont(ofSize: 11), color: secondary)
                draw("사용자가 선택한 기록 요약이며 진단·치료를 대신하지 않습니다.", in: CGRect(x: 48, y: 780, width: 499, height: 24), font: .systemFont(ofSize: 10), color: secondary)
                y = 116
            }
            func line(_ text: String, heading: Bool = false) {
                let font = heading ? UIFont.boldSystemFont(ofSize: 14) : UIFont.systemFont(ofSize: 12)
                let height = ceil((text as NSString).boundingRect(with: CGSize(width: 499, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height) + 8
                if y + height > 752 { newPage() }
                draw(text, in: CGRect(x: 48, y: y, width: 499, height: height), font: font, color: ink)
                y += height + 6
            }
            newPage()
            line("포함 항목: " + report.selectedLabels.joined(separator: ", "))
            line("출처: " + report.source)
            if let average = report.averageMinutes { line("선택한 수면 \(report.sleepRows.count)일 평균 \(duration(average))", heading: true) }
            if !report.sleepRows.isEmpty {
                line("선택한 날짜의 수면", heading: true)
                for row in report.sleepRows {
                    var text = row.date.formatted(.dateTime.year().month().day())
                    if let total = row.totalMinutes { text += " · " + duration(total) }
                    if let stages = row.stages { text += "\n" + stages }
                    line(text)
                }
            }
            if report.includesCheckIns {
                line("선택한 체크인 \(report.checkInRows.count)건", heading: true)
                for row in report.checkInRows {
                    line(row.date.formatted(.dateTime.year().month().day()) + " · " + row.fields.joined(separator: " · "))
                }
            }
        }
        try data.write(to: url, options: .atomic)
        return url
    }
    private static func duration(_ value: Int) -> String { "\(value / 60)시간 \(value % 60)분" }
    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color])
    }
    private static func removeExpiredReports() {
        let manager = FileManager.default
        let files = (try? manager.contentsOfDirectory(at: manager.temporaryDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.lastPathComponent.hasPrefix("Jammanbo-Sleep-Summary-") && file.pathExtension == "pdf" {
            if let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modified < Date.now.addingTimeInterval(-86400) { try? manager.removeItem(at: file) }
        }
    }
}
