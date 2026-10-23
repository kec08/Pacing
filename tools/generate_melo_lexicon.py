"""Generate the restricted Korean pronunciation lexicon for Pacing's running prompts.

Requires g2pkk==0.1.2 and a working Mecab Korean dictionary. The app uses this
checked-in output; no Python or network access is needed on the device.
"""
import json
import unicodedata
from pathlib import Path
from g2pkk import G2p

ROOT = Path(__file__).resolve().parents[1]
symbols = json.loads((ROOT / 'Pacing/Pacing/Core/Audio/Melo/melotts_kr_config.json').read_text())['symbols']
SYMBOLS = {symbol: index for index, symbol in enumerate(symbols)}
G2P = G2p()


def korean_number(value):
    if value == 0:
        return '영'
    digits = '일이삼사오육칠팔구'
    result = ''
    for place, suffix in ((100, '백'), (10, '십'), (1, '')):
        digit, value = divmod(value, place)
        if digit:
            result += ('' if place > 1 and digit == 1 else digits[digit - 1]) + suffix
    return result
LITERALS = [
    '러닝을 시작할게요.', '잠시 멈출게요.', '다시 달려볼게요.',
    '달렸어요. 구간 기록은', ', 평균 페이스는', '예요.',
    '러닝을 마쳤어요. 총 거리', ', 시간은',
    '예요. 평균 페이스는', '예요. 평균 페이스는 아직 확인되지 않았어요.',
    '점', '킬로미터',
]

def ids(text):
    pronunciation = G2P(text)
    chars = (char for char in unicodedata.normalize('NFD', pronunciation) if not char.isspace())
    return [SYMBOLS[char] for char in chars]

lexicon = {text: ids(text) for text in LITERALS}
for value in range(1000):
    spoken = korean_number(value)
    lexicon[f'__number_{value}'] = ids(spoken)
    lexicon[f'{value}킬로미터'] = ids(f'{spoken}킬로미터')
    lexicon[f'{value}분'] = ids(f'{spoken}분')
for value in range(100):
    lexicon[f'{value}시간'] = ids(f'{korean_number(value)}시간')
for value in range(60):
    lexicon[f'{value}초'] = ids(f'{korean_number(value)}초')
output = ROOT / 'Pacing/Pacing/Core/Audio/Melo/korean_lexicon.json'
output.write_text(json.dumps(lexicon, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'{len(lexicon)} pronunciations, {output.stat().st_size} bytes')
