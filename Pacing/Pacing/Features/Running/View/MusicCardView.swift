import SwiftUI
import MusicKit

struct MusicCardView: View {
    let track: Track?
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 앨범 아트
                Group {
                    if let artwork = track?.artwork {
                        ArtworkImage(artwork, width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.backgroundSecondary)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.textSecondary)
                            }
                    }
                }

                // 트랙 정보
                VStack(alignment: .leading, spacing: 2) {
                    if isLoading {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.backgroundSecondary)
                            .frame(width: 120, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.backgroundSecondary)
                            .frame(width: 80, height: 12)
                    } else if let track {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text(track.artistName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Apple Music 연결")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("탭하여 음악 선택")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "music.note.list")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.main500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }
}
