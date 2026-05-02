import SwiftUI

struct TransientNotice: Identifiable, Equatable {
    let id = UUID()
    let message: String

    static func == (lhs: TransientNotice, rhs: TransientNotice) -> Bool {
        lhs.id == rhs.id
    }
}

struct TransientNoticeView: View {
    let notice: TransientNotice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.tint)
            Text(notice.message)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.25))
        }
        .shadow(radius: 8, y: 3)
    }
}
