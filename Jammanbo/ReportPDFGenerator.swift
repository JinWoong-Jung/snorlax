import Foundation
import UIKit

enum ReportPDFGenerator {
    static func create(nights: [SleepNight], checkIns: [CheckIn], source: String) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Jammanbo-Sleep-Summary.pdf")
        let data = renderer.pdfData { context in
            context.beginPage()
            let ink = UIColor(red: 0.10, green: 0.15, blue: 0.25, alpha: 1)
            let secondary = UIColor(red: 0.35, green: 0.41, blue: 0.50, alpha: 1)
            let accent = UIColor(red: 0.16, green: 0.53, blue: 0.48, alpha: 1)

            draw("잠만보 · 수면 기록 요약", at: CGPoint(x: 48, y: 48), font: .boldSystemFont(ofSize: 24), color: ink)
            draw("생성일  \(Date.now.formatted(.dateTime.year().month().day()))", at: CGPoint(x: 48, y: 84), font: .systemFont(ofSize: 11), color: secondary)
            context.cgContext.setFillColor(accent.cgColor)
            context.cgContext.fill(CGRect(x: 48, y: 116, width: 499, height: 2))

            let average = nights.isEmpty ? 0 : nights.reduce(0) { $0 + $1.totalMinutes } / nights.count
            draw("최근 기록", at: CGPoint(x: 48, y: 143), font: .boldSystemFont(ofSize: 15), color: ink)
            draw("분석 기간  최근 \(nights.count)일", at: CGPoint(x: 48, y: 174), font: .systemFont(ofSize: 12), color: secondary)
            draw("평균 수면  \(average / 60)시간 \(average % 60)분", at: CGPoint(x: 48, y: 198), font: .boldSystemFont(ofSize: 18), color: accent)
            draw("체크인 기록  \(checkIns.count)건", at: CGPoint(x: 48, y: 229), font: .systemFont(ofSize: 12), color: secondary)
            draw("데이터 출처  \(source)", at: CGPoint(x: 48, y: 251), font: .systemFont(ofSize: 12), color: secondary)

            draw("날짜별 기록", at: CGPoint(x: 48, y: 298), font: .boldSystemFont(ofSize: 15), color: ink)
            var y: CGFloat = 330
            for night in nights.prefix(10) {
                let date = night.date.formatted(.dateTime.year().month(.abbreviated).day())
                draw(date, at: CGPoint(x: 48, y: y), font: .systemFont(ofSize: 12), color: ink)
                draw(night.durationLabel, at: CGPoint(x: 230, y: y), font: .systemFont(ofSize: 12, weight: .semibold), color: ink)
                draw("깊은 잠 \(night.deepMinutes / 60)h \(night.deepMinutes % 60)m  ·  렘수면 \(night.remMinutes / 60)h \(night.remMinutes % 60)m", at: CGPoint(x: 355, y: y), font: .systemFont(ofSize: 9), color: secondary)
                context.cgContext.setStrokeColor(UIColor(white: 0.87, alpha: 1).cgColor)
                context.cgContext.move(to: CGPoint(x: 48, y: y + 21))
                context.cgContext.addLine(to: CGPoint(x: 547, y: y + 21))
                context.cgContext.strokePath()
                y += 34
            }

            draw("이 문서는 사용자가 기록한 건강 정보를 정리한 참고 자료입니다. 진단서가 아니며 질환의 진단이나 치료를 대신하지 않습니다.", at: CGPoint(x: 48, y: 758), font: .systemFont(ofSize: 10), color: secondary)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }
}
