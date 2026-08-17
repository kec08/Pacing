import SwiftUI

struct ProfileVisibilitySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: MyViewModel

    @State private var selection: ProfileVisibility
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(viewModel: MyViewModel) {
        self.viewModel = viewModel
        _selection = State(initialValue: viewModel.profileVisibility)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("내 프로필을 볼 수 있는 범위를 선택하세요.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textSecondary)

                VStack(spacing: 10) {
                    ForEach(ProfileVisibility.allCases) { visibility in
                        Button { selection = visibility } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon(for: visibility))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(selection == visibility ? Color.main500 : Color.textSecondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(visibility.title)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Color.textPrimary)
                                    Text(visibility.description)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: selection == visibility ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(selection == visibility ? Color.main500 : Color.gray300)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selection == visibility ? Color.main500.opacity(0.10) : Color.backgroundSecondary)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selection == visibility ? Color.main500.opacity(0.38) : Color.surfaceBorder, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("프로필 공개 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { Task { await save() } }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.main500)
                    .disabled(isSaving)
            }
        }
        .alert("공개 설정 오류", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await viewModel.saveProfileVisibility(selection)
            dismiss()
        } catch {
            errorMessage = "프로필 공개 설정을 저장하지 못했어요."
        }
    }

    private func icon(for visibility: ProfileVisibility) -> String {
        switch visibility {
        case .public: "globe"
        case .friendsOnly: "person.2.fill"
        case .private: "lock.fill"
        }
    }
}
