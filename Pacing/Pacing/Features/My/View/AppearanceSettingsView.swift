import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(AppAppearance.allCases) { appearance in
                    appearanceRow(appearance)

                    if appearance != AppAppearance.allCases.last {
                        Divider()
                            .padding(.leading, 104)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("화면 모드")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func appearanceRow(_ appearance: AppAppearance) -> some View {
        Button {
            appState.setAppearance(appearance)
        } label: {
            HStack(spacing: 16) {
                AppearancePreview(mode: appearance)

                VStack(alignment: .leading, spacing: 7) {
                    Text(appearance.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    if let description = appearance.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: appState.appearance == appearance ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(appState.appearance == appearance ? Color.main500 : Color.gray400)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: appearance == .system ? 120 : 104)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appearance.title)
        .accessibilityValue(appState.appearance == appearance ? "선택됨" : "선택 안 됨")
        .accessibilityHint("두 번 탭하여 이 화면 모드로 변경합니다")
    }
}

private struct AppearancePreview: View {
    let mode: AppAppearance

    var body: some View {
        ZStack {
            if mode == .system {
                HStack(spacing: 0) {
                    previewContent(isDark: false)
                    previewContent(isDark: true)
                }
            } else {
                previewContent(isDark: mode == .dark)
            }
        }
        .frame(width: 68, height: 82)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray300, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func previewContent(isDark: Bool) -> some View {
        let previewBackground = isDark ? Color(red: 0.10, green: 0.10, blue: 0.10) : Color.white
        let previewPrimary = isDark ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color(red: 0.11, green: 0.11, blue: 0.12)
        let previewSecondary = isDark ? Color(red: 0.32, green: 0.32, blue: 0.34) : Color(red: 0.78, green: 0.78, blue: 0.80)

        VStack(alignment: .leading, spacing: 6) {
            Text("P")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.main500)
            Capsule().fill(previewPrimary).frame(width: 22, height: 4)
            Capsule().fill(previewSecondary).frame(width: 30, height: 3)
            Capsule().fill(previewSecondary).frame(width: 25, height: 3)
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(previewBackground)
    }
}
