import MyDeskCore
import SwiftUI

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKeys.canvasScrollZoomDirection) private var scrollZoomDirectionRaw = CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = CanvasZoomBaseline.defaultPercent

    var body: some View {
        Form {
            Section {
                Picker("滚轮缩放方向", selection: $scrollZoomDirectionRaw) {
                    ForEach(CanvasScrollZoomDirection.allCases) { direction in
                        Text(direction.title)
                            .tag(direction.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("控制鼠标滚轮或触控板纵向滚动时画布的缩放方向。双指捏合缩放仍保持系统手势行为。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Stepper(value: $canvasDefaultZoomPercent, in: 25...500, step: 25) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("默认 100% 对应实际缩放")
                        Text("\(Int(canvasDefaultZoomPercent.rounded()))% 实际缩放显示为 Canvas 里的 100%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Canvas")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}
