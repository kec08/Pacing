import SwiftUI
import FirebaseAuth

struct ProfileSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 1

    @State private var nickname: String = ""
    @State private var gender: String = "선택 안 함"
    @State private var age: Int = 25
    @State private var height: Int = 170
    @State private var weight: Int = 65
    @State private var isSaving = false

    private let genders = ["남", "여", "선택 안 함"]

    var body: some View {
        VStack(spacing: 0) {
            // 진행 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.gray100).frame(height: 3)
                    Rectangle()
                        .fill(Color.main500)
                        .frame(width: geo.size.width * CGFloat(step) / 3, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: step)
                }
            }
            .frame(height: 3)

            Group {
                switch step {
                case 1: step1
                case 2: step2
                default: step3
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
            .animation(.easeInOut(duration: 0.25), value: step)
        }
        .background(Color.backgroundPrimary)
    }

    // MARK: - Step 1: 닉네임
    private var step1: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "닉네임을 알려주세요", subtitle: "Pacing에서 사용할 이름이에요")

            VStack(alignment: .leading, spacing: 8) {
                Text("닉네임")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                TextField("닉네임을 입력하세요 (최대 12자)", text: $nickname)
                    .onChange(of: nickname) { _, new in
                        if new.count > 12 { nickname = String(new.prefix(12)) }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            nextButton(label: "다음", enabled: !nickname.trimmingCharacters(in: .whitespaces).isEmpty) {
                step = 2
            }
        }
    }

    // MARK: - Step 2: 성별 / 나이
    private var step2: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "기본 정보를 입력해주세요", subtitle: "성별과 나이를 선택해주세요")

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("성별")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Picker("성별", selection: $gender) {
                        ForEach(genders, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("나이")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Picker("나이", selection: $age) {
                        ForEach(1...100, id: \.self) { Text("\($0) 세") }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            nextButton(label: "다음", enabled: true) {
                step = 3
            }
        }
    }

    // MARK: - Step 3: 키 / 체중
    private var step3: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepHeader(title: "신체 정보를 입력해주세요", subtitle: "더 정확한 러닝 데이터를 위해 필요해요")

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("키 (cm)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Picker("키", selection: $height) {
                        ForEach(100...250, id: \.self) { Text("\($0) cm") }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("체중 (kg)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Picker("체중", selection: $weight) {
                        ForEach(20...200, id: \.self) { Text("\($0) kg") }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            nextButton(label: "시작하기", enabled: !isSaving) {
                Task { await saveProfile() }
            }
        }
    }

    // MARK: - 공통 컴포넌트

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private func nextButton(label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isSaving && label == "시작하기" {
                    ProgressView().tint(.white)
                } else {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(enabled ? Color.main500 : Color.gray300)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    // MARK: - 저장

    private func saveProfile() async {
        isSaving = true
        UserDefaults.standard.set(nickname, forKey: "nickname")
        UserDefaults.standard.set(height,   forKey: "height")
        UserDefaults.standard.set(weight,   forKey: "weight")
        UserDefaults.standard.set(age,      forKey: "age")

        if let uid = Auth.auth().currentUser?.uid {
            try? await FirestoreService.shared.saveUserProfile(
                uid: uid, nickname: nickname, height: height, weight: weight, age: age
            )
        }

        appState.isLoggedIn = true
        appState.isProfileComplete = true
        isSaving = false
    }
}
