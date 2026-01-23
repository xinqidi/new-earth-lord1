import SwiftUI

/// 圆形进度视图
/// 显示建造或升级的进度（0.0~1.0）
struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: 3
                )

            // 进度圆环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)

            // 百分比文本
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
        }
        .frame(width: 32, height: 32)
    }
}

#Preview {
    VStack(spacing: 20) {
        CircularProgressView(progress: 0.0)
        CircularProgressView(progress: 0.25)
        CircularProgressView(progress: 0.5)
        CircularProgressView(progress: 0.75)
        CircularProgressView(progress: 1.0)
    }
    .padding()
}
