import SwiftUI

struct AccountDeletionView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: MyViewModel

    @State private var confirmationText = ""

    private let confirmationPhrase = "탈퇴하겠습니다."

    private var canDelete: Bool {
        confirmationText == confirmationPhrase && !viewModel.isDeletingAccount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("회원탈퇴")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 32)

            Text("탈퇴 시 아래 내용이 적용됩니다.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 44)

            VStack(alignment: .leading, spacing: 14) {
                deletionItem("프로필, 신체 정보, 러닝 기록 및 최근 음악 기록이 삭제됩니다.")
                deletionItem("친구 관계, 친구 요청, 공유 플레이리스트와 같이 듣기 정보가 삭제됩니다.")
                deletionItem("삭제된 데이터는 복구할 수 없습니다.")
            }
            .padding(.top, 20)

            Divider()
                .padding(.vertical, 32)

            Text("탈퇴를 확인하려면 아래에 \"\(confirmationPhrase)\"를 입력하세요.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            TextField(confirmationPhrase, text: $confirmationText)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 14)
                .accessibilityLabel("회원탈퇴 확인 문구")

            if let errorMessage = viewModel.accountDeletionError {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accent500)
                    .padding(.top, 12)
                    .accessibilityLabel("회원탈퇴 오류: \(errorMessage)")
            }

            Spacer(minLength: 28)

            Button(action: deleteAccount) {
                Group {
                    if viewModel.isDeletingAccount {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("탈퇴하기")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canDelete ? Color.accent500 : Color.gray300)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!canDelete)
            .accessibilityHint("입력 문구가 정확할 때 계정과 관련 데이터가 영구 삭제됩니다")
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .background(Color.backgroundPrimary)
        .navigationTitle("회원탈퇴")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isDeletingAccount)
        .interactiveDismissDisabled(viewModel.isDeletingAccount)
        .onDisappear {
            viewModel.accountDeletionError = nil
        }
    }

    private func deletionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 15))
        .foregroundStyle(Color.textSecondary)
    }

    private func deleteAccount() {
        Task { @MainActor in
            await viewModel.deleteAccount(appState: appState)
        }
    }
}
