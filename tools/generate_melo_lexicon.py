"""Generate the restricted Korean pronunciation lexicon for Pacing's running prompts.

Requires g2pkk==0.1.2 and a working Mecab Korean dictionary. The app uses this
checked-in output; no Python or network access is needed on the device.
"""
import json
import unicodedata
from pathlib import Path
from g2pkk import G2p

ROOT = Path(__file__).resolve().parents[1]
SYMBOLS = json.loads((ROOT / 'Pacing/Pacing/Core/Audio/Melo/symbols.json').read_text())['symbol_to_id']
G2P = G2p()
LITERALS = [
    '운동을 시작합니다.', '운동을 정지합니다.', '운동을 재개합니다.',
    '.', '. 킬로미터당 페이스',
    '운동을 완료했습니다. 총 거리', '. 총 시간',
    '. 평균 페이스', '. 평균 페이스 정보 없음.',
    '점', '킬로미터',
]

def ids(text):
    pronunciation = G2P(text)
    chars = (char for char in unicodedata.normalize('NFD', pronunciation) if not char.isspace())
    return [SYMBOLS[char] for char in chars]

lexicon = {text: ids(text) for text in LITERALS}
for value in range(1000):
    lexicon[f'__number_{value}'] = ids(str(value))
    lexicon[f'{value}킬로미터'] = ids(f'{value}킬로미터')
    lexicon[f'{value}분'] = ids(f'{value}분')
for value in range(100):
    lexicon[f'{value}시간'] = ids(f'{value}시간')
for value in range(60):
    lexicon[f'{value}초'] = ids(f'{value}초')
output = ROOT / 'Pacing/Pacing/Core/Audio/Melo/korean_lexicon.json'
output.write_text(json.dumps(lexicon, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'{len(lexicon)} pronunciations, {output.stat().st_size} bytes')
