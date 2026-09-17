import SwiftUI

struct WatchRunControlsTabView: View {
    @ObservedObject var viewModel: WatchRunningViewModel

    var body: some View {
        HStack(spacing: 18) {
            Button { viewModel.pauseOrResume() } label: {
                Image(systemName: viewModel.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(viewModel.state == .paused ? .white : .black)
                    .frame(width: 66, height: 66)
                    .background(
                        viewModel.state == .paused ? PacingWatchTheme.main500 : Color.white,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.state == .paused ? "러닝 재개" : "러닝 일시정지")

            Button { viewModel.requestEnd() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(Color.gray.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("러닝 종료")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("러닝을 종료할까요?", isPresented: $viewModel.isEndConfirmationPresented) {
            Button("계속 러닝", role: .cancel) {}
            Button("종료", role: .destructive) { viewModel.end() }
        } message: {
            Text("현재 러닝을 종료하고 기록을 저장합니다.")
        }
    }
}
