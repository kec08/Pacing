const fs = require('fs');
const path = require('path');

const cards = [
  { file: '01-pacing-intro', image: 'source/hero.jpg', eyebrow: 'RUN WITH THE SAME RHYTHM', title: ['같은 음악,', '같은 페이스'], body: '음악으로 연결되는 새로운 러닝 경험', hero: true },
  { file: '02-running-overview', image: 'source/home.png', eyebrow: 'MY RUNNING', title: ['오늘의 러닝을', '한눈에'], body: '거리, 시간, 페이스까지 나만의 기록을 확인하세요', accent: '#FF2D55' },
  { file: '03-run-with-map', image: 'source/running.png', eyebrow: 'RUN WITH PACING', title: ['달리는 순간을', '기록하세요'], body: '지도 위에서 나의 경로와 페이스를 남겨보세요', accent: '#B640E5' },
  { file: '04-music', image: 'source/music.png', eyebrow: 'MUSIC FOR RUNNING', title: ['나만의 리듬으로', '더 멀리'], body: '러닝에 어울리는 음악과 함께 달려보세요', accent: '#FF2D55' },
  { file: '05-listen-together', image: 'source/listen-together.png', eyebrow: 'LISTEN TOGETHER', title: ['같은 음악으로', '함께 달려요'], body: '주변 러너와 실시간으로 음악을 같이 들어보세요', accent: '#8B3CDB' },
  { file: '06-activity-detail', image: 'source/record.png', eyebrow: 'RUN ANALYTICS', title: ['나의 기록이', '쌓이는 즐거움'], body: '거리, 시간, 경로를 되돌아보며 다음 러닝을 준비하세요', accent: '#FF2D55' },
  { file: '07-friends', image: 'source/friends.png', eyebrow: 'RUNNING MATES', title: ['음악 취향으로', '연결되는 러너들'], body: '친구를 찾고 함께할 러닝 메이트를 만나보세요', accent: '#9B3EDE' },
  { file: '08-playlists', image: 'source/playlists.png', eyebrow: 'DISCOVER PLAYLISTS', title: ['새로운 음악으로', '새로운 러닝'], body: '러너들의 플레이리스트를 발견하고 바로 들어보세요', accent: '#FF2D55' },
];

function svgFor(card) {
  const bg = card.hero
    ? `<image href="${card.image}" x="0" y="0" width="1242" height="2688" preserveAspectRatio="xMidYMid slice"/>\n       <rect width="1242" height="2688" fill="#160019" opacity="0.12"/>`
    : `<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#fff5f8"/><stop offset="0.52" stop-color="#ffffff"/><stop offset="1" stop-color="#faf3ff"/></linearGradient><radialGradient id="glow"><stop stop-color="${card.accent}" stop-opacity="0.22"/><stop offset="1" stop-color="${card.accent}" stop-opacity="0"/></radialGradient><filter id="shadow" x="-30%" y="-20%" width="160%" height="160%"><feDropShadow dx="0" dy="30" stdDeviation="35" flood-color="#241019" flood-opacity="0.22"/></filter><clipPath id="screen"><rect x="185" y="695" width="872" height="1896" rx="84"/></clipPath></defs><rect width="1242" height="2688" fill="url(#bg)"/><circle cx="1120" cy="410" r="560" fill="url(#glow)"/><circle cx="-90" cy="2550" r="530" fill="url(#glow)"/>`;
  const titleColor = card.hero ? '#fff' : '#171116';
  const bodyColor = card.hero ? '#fff' : '#5b5057';
  const eyebrow = card.hero ? '#fff' : card.accent;
  const frame = card.hero ? '' : `<g filter="url(#shadow)"><rect x="154" y="664" width="934" height="1958" rx="115" fill="#19161a"/><rect x="171" y="681" width="900" height="1924" rx="99" fill="#000"/><image href="${card.image}" x="185" y="695" width="872" height="1896" preserveAspectRatio="xMidYMid slice" clip-path="url(#screen)"/></g>`;
  const deviceTitle = card.hero ? '' : `<rect x="527" y="676" width="188" height="42" rx="21" fill="#000"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1242" height="2688" viewBox="0 0 1242 2688">
    ${bg}
    ${card.hero ? `<rect x="66" y="136" width="210" height="52" rx="26" fill="#fff" fill-opacity="0.18"/><text x="171" y="172" text-anchor="middle" fill="#fff" font-family="Apple SD Gothic Neo, NanumSquare, sans-serif" font-size="24" font-weight="700" letter-spacing="2">PACING</text>` : ''}
    <text x="80" y="${card.hero ? '326' : '160'}" fill="${eyebrow}" font-family="Apple SD Gothic Neo, NanumSquare, sans-serif" font-size="29" font-weight="800" letter-spacing="2">${card.eyebrow}</text>
    <text x="80" y="${card.hero ? '468' : '310'}" fill="${titleColor}" font-family="Apple SD Gothic Neo, NanumSquare, sans-serif" font-size="88" font-weight="800" letter-spacing="-4"><tspan x="80" dy="0">${card.title[0]}</tspan><tspan x="80" dy="106">${card.title[1]}</tspan></text>
    <text x="82" y="${card.hero ? '690' : '550'}" fill="${bodyColor}" font-family="Apple SD Gothic Neo, NanumSquare, sans-serif" font-size="33" font-weight="500" letter-spacing="-1">${card.body}</text>
    ${frame}${deviceTitle}
    ${card.hero ? `<text x="621" y="2500" text-anchor="middle" fill="#fff" fill-opacity="0.82" font-family="Apple SD Gothic Neo, NanumSquare, sans-serif" font-size="28" font-weight="700" letter-spacing="3">RUN. LISTEN. CONNECT.</text>` : `<text x="621" y="2640" text-anchor="middle" fill="#8d7c86" font-family="Apple SD Gothic Neo, NanumSquare, sans-serif" font-size="24" font-weight="700" letter-spacing="3">PACING</text>`}
  </svg>`;
}

for (const card of cards) {
  fs.writeFileSync(path.join(__dirname, `${card.file}.svg`), svgFor(card));
}
