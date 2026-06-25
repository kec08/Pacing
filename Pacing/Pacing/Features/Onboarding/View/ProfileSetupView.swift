import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var nickname: String = ""
    @State private var height: Int = 170
    @State private var weight: Int = 65
    @State private var age: Int = 25
    @State private var gender: String = "선택 안 함"

    private let genders = ["남", "여", "선택 안 함"]
    private var isValid: Bool { !nickname.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // 헤더
                VStack(alignment: .leading, spacing: 6) {
                    Text("프로필 설정")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.textPrimary)
                    Text("나에 맞는 러닝 경험을 위해 정보를 입력해주세요")
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                }
                .padding(.top, 24)

                // 닉네임
                VStack(alignment: .leading, spacing: 8) {
                    Text("닉네임")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    TextField("닉네임을 입력하세요 (최대 12자)", text: $nickname)
                        .onChange(of: nickname) { _, new in
                            if new.count > 12 { nickname = String(new.prefix(12)) }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.gray100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 키
                VStack(alignment: .leading, spacing: 8) {
                    Text("키 (cm)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Picker("키", selection: $height) {
                        ForEach(100...250, id: \.self) { Text("\($0) cm") }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 체중
                VStack(alignment: .leading, spacing: 8) {
                    Text("체중 (kg)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Picker("체중", selection: $weight) {
                        ForEach(20...200, id: \.self) { Text("\($0) kg") }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 나이
                VStack(alignment: .leading, spacing: 8) {
                    Text("나이")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Picker("나이", selection: $age) {
                        ForEach(1...100, id: \.self) { Text("\($0) 세") }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // 성별
                VStack(alignment: .leading, spacing: 8) {
                    Text("성별")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textSecondary)
                    Picker("성별", selection: $gender) {
                        ForEach(genders, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // 시작하기 버튼
                Button {
                    // TODO: Firestore 저장
                    appState.isProfileComplete = true
                } label: {
                    Text("시작하기")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isValid ? Color.main500 : Color.gray300)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.backgroundPrimary)
    }
}
