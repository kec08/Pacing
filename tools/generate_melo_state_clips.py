"""Render instant offline MeloTTS clips for the three fixed running states.

Requires numpy and onnxruntime. Dynamic lap and finish prompts still run ONNX on iPhone.
"""
import json
import wave
from pathlib import Path

import numpy as np
import onnxruntime as ort

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'Pacing/Pacing/Core/Audio/Melo'
lexicon = json.loads((ASSETS / 'korean_lexicon.json').read_text())
session = ort.InferenceSession(str(ASSETS / 'melotts_kr_int8.onnx'), providers=['CPUExecutionProvider'])

for name, text in {
    'started': '러닝을 시작합니다.',
    'paused': '운동을 정지합니다.',
    'resumed': '운동을 재개합니다.',
    'completed': '운동을 완료했습니다.',
}.items():
    phones = [0] + lexicon[text] + [0]
    tokens = np.array([[value for index, phone in enumerate(phones)
                        for value in ([0, phone] if index else [phone])]], dtype=np.int64)
    length = tokens.shape[1]
    inputs = {
        'x': tokens,
        'x_lengths': np.array([length], dtype=np.int64),
        'sid': np.array([0], dtype=np.int64),
        'tone': np.where(tokens == 0, 0, 11).astype(np.int64),
        'language': np.where(tokens == 0, 0, 4).astype(np.int64),
        'bert': np.zeros((1, 1024, length), dtype=np.float32),
        'ja_bert': np.zeros((1, 768, length), dtype=np.float32),
        'noise_scale': np.array(0.6, dtype=np.float32),
        'length_scale': np.array(1.08, dtype=np.float32),
        'noise_scale_w': np.array(0.8, dtype=np.float32),
        'sdp_ratio': np.array(0.2, dtype=np.float32),
    }
    audio = session.run(['audio'], inputs)[0]
    brightened = audio.copy()
    brightened[1:] += 0.12 * (audio[1:] - audio[:-1])
    with wave.open(str(ASSETS / f'melo_{name}.wav'), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(48_000)
        output.writeframes((np.clip(brightened, -1, 1) * 32_767).astype('<i2').tobytes())
    print(name, round(len(audio) / 48_000, 2), 'seconds')
