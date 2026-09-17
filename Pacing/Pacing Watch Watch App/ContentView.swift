//
//  ContentView.swift
//  Pacing Watch Watch App
//
//  Created by 김은찬 on 9/17/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            PacingWatchTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                Image("PacingWatchMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                .accessibilityLabel("Pacing")

                VStack(spacing: 4) {
                    Text("Pacing")
                        .font(.headline)
                        .foregroundStyle(PacingWatchTheme.textPrimary)

                    Text("워치 준비 완료")
                        .font(.caption2)
                        .foregroundStyle(PacingWatchTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("러닝 기록", systemImage: "iphone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PacingWatchTheme.main500)

                    Text("iPhone의 Pacing 앱에서 러닝을 시작하면 워치에서도 실시간 기록을 확인할 수 있어요.")
                        .font(.caption2)
                        .foregroundStyle(PacingWatchTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(PacingWatchTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    ContentView()
}

/// iPhone 앱의 PacingColor를 Watch의 작은 화면과 기본 다크 모드에 맞춰 축약한 색상 토큰입니다.
enum PacingWatchTheme {
    static let main500 = Color(red: 1.0, green: 0.216, blue: 0.373) // #FF375F
    static let magenta = Color(red: 0.85, green: 0.12, blue: 0.55)
    static let purple = Color(red: 0.42, green: 0.19, blue: 0.90)

    static let background = Color(red: 0.067, green: 0.067, blue: 0.067) // #111111
    static let surface = Color(red: 0.106, green: 0.106, blue: 0.106) // #1B1B1B
    static let textPrimary = Color(red: 0.961, green: 0.961, blue: 0.969) // #F5F5F7
    static let textSecondary = Color(red: 0.682, green: 0.682, blue: 0.698) // #AEAEB2

    static let brandGradient = LinearGradient(
        colors: [main500, magenta, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
