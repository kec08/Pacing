import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var vm: MyViewModel

    @State private var nickname: String
    @State private var ageText: String
    @State private var heightText: String
    @State private var weightText: String
    @State private var profileImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(vm: MyViewModel) {
        self.vm = vm
        _nickname = State(initialValue: vm.nickname)
        _ageText = State(initialValue: vm.age > 0 ? String(vm.age) : "")
        _heightText = State(initialValue: vm.height > 0 ? String(vm.height) : "")
        _weightText = State(initialValue: vm.weight > 0 ? String(vm.weight) : "")
        _profileImage = State(initialValue: vm.profileImage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoSection
                    introSection
                    infoSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(background)
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("저장")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
            .alert("프로필 수정 오류", isPresented: errorBinding) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.main200.opacity(0.25),
                Color.backgroundSecondary,
                Color.backgroundPrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var photoSection: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(Color.gray100)
                                .frame(width: 104, height: 104)

                            if let profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 104, height: 104)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.gray300)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        }
                        .shadow(color: Color.main500.opacity(0.12), radius: 14, y: 8)

                        Circle()
                            .fill(Color.main500)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                    }

                    Text("프로필 사진 변경")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.main500)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: photoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = image
                    }
                }
            }

            Text("마이 탭과 친구 화면에 보여질 내 프로필 사진이에요.")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("프로필 정보")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text("친구에게 보여질 내 정보를 간결하게 정리할 수 있어요.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            fieldRow(
                title: "이름",
                value: $nickname,
                keyboardType: .default,
                trailingText: ""
            )
            divider
            fieldRow(
                title: "나이",
                value: $ageText,
                keyboardType: .numberPad,
                trailingText: "세"
            )
            divider
            fieldRow(
                title: "키",
                value: $heightText,
                keyboardType: .numberPad,
                trailingText: "cm"
            )
            divider
            fieldRow(
                title: "몸무게",
                value: $weightText,
                keyboardType: .numberPad,
                trailingText: "kg"
            )
        }
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 20)
    }

    private func fieldRow(
        title: String,
        value: Binding<String>,
        keyboardType: UIKeyboardType,
        trailingText: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textPrimary)

            Spacer(minLength: 8)

            TextField("", text: value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .onChange(of: value.wrappedValue) { _, newValue in
                    if title == "이름" {
                        if newValue.count > 12 {
                            value.wrappedValue = String(newValue.prefix(12))
                        }
                    } else {
                        value.wrappedValue = newValue.filter(\.isNumber)
                    }
                }

            Text(trailingText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
                .frame(minWidth: 36, alignment: .trailing)
                .opacity(trailingText.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
    }

    private func save() async {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            errorMessage = "닉네임을 입력해주세요."
            return
        }

        guard let age = Int(ageText), (1...100).contains(age) else {
            errorMessage = "나이는 1세부터 100세 사이로 입력해주세요."
            return
        }

        guard let height = Int(heightText), (100...250).contains(height) else {
            errorMessage = "키는 100cm부터 250cm 사이로 입력해주세요."
            return
        }

        guard let weight = Int(weightText), (20...200).contains(weight) else {
            errorMessage = "몸무게는 20kg부터 200kg 사이로 입력해주세요."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await vm.saveProfile(
                nickname: trimmedNickname,
                age: age,
                height: height,
                weight: weight,
                profileImage: profileImage
            )
            dismiss()
        } catch {
            errorMessage = "프로필을 저장하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
