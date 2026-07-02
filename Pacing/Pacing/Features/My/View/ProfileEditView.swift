import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var vm: MyViewModel

    @State private var nickname: String
    @State private var age: Int
    @State private var height: Int
    @State private var weight: Int
    @State private var profileImage: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false

    init(vm: MyViewModel) {
        self.vm = vm
        _nickname = State(initialValue: vm.nickname)
        _age = State(initialValue: max(vm.age, 1))
        _height = State(initialValue: max(vm.height, 100))
        _weight = State(initialValue: max(vm.weight, 20))
        _profileImage = State(initialValue: vm.profileImage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoSection
                    nicknameSection
                    pickerSection(title: "나이", selection: $age, range: 1...100, unit: "세")
                    pickerSection(title: "키", selection: $height, range: 100...250, unit: "cm")
                    pickerSection(title: "몸무게", selection: $weight, range: 20...200, unit: "kg")
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("프로필 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
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
                    .disabled(isSaving || nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.gray100)
                            .frame(width: 96, height: 96)

                        if let profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(Color.gray300)
                        }
                    }

                    Circle()
                        .fill(Color.main500)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
            }
            .onChange(of: photoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = image
                    }
                }
            }

            Text("프로필 사진")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("이름")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            TextField("닉네임을 입력하세요", text: $nickname)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: nickname) { _, newValue in
                    if newValue.count > 12 {
                        nickname = String(newValue.prefix(12))
                    }
                }
        }
    }

    private func pickerSection(title: String, selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)

            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text("\(value)\(unit)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .background(Color.gray100)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await vm.saveProfile(
                nickname: nickname,
                age: age,
                height: height,
                weight: weight,
                profileImage: profileImage
            )
            dismiss()
        } catch {
        }
    }
}
