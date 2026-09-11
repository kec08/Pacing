# Before — 카탈로그 ID 요청

카탈로그 곡 ID를 모두 하나의 `MusicCatalogResourceRequest`에 넣고 limit을 25로 설정했다. 25개를 초과한 ID가 응답에 포함되지 않으면 해당 곡들이 제목·아티스트 검색 fallback으로 다시 요청될 수 있었다.
