import SwiftUI

enum JammanboPalette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.105)
    static let surface = Color(red: 0.075, green: 0.105, blue: 0.17)
    static let raised = Color(red: 0.11, green: 0.15, blue: 0.23)
    static let accent = Color(red: 0.45, green: 0.85, blue: 0.77)
    static let lilac = Color(red: 0.72, green: 0.67, blue: 0.98)
    static let muted = Color(red: 0.62, green: 0.68, blue: 0.78)
    static let coral = Color(red: 1.0, green: 0.62, blue: 0.51)
}

struct SoftCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JammanboPalette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
