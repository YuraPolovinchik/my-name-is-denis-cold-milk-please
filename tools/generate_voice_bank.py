r"""Generate the complete offline dialogue bank with the installed OmniVoice.

Run with:
    C:\Users\admin\orc\venv\Scripts\python.exe tools\generate_voice_bank.py

The model is loaded once. Stable reference clips keep Rita, Denis and the
remote colleague recognisable across every generated line.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

import soundfile as sf
import torch

from omnivoice.models.omnivoice import OmniVoice


PROJECT_ROOT = Path(__file__).resolve().parents[1]
VOICE_ROOT = PROJECT_ROOT / "assets" / "voices"
MODEL_ID = "k2-fsa/OmniVoice"

VOICE_LINES: dict[str, list[str]] = {
    "rita": [
        "Денис... телевизор слишком громко. Выключи звук, пожалуйста.",
        "Блядь... всё. Выходи. Разбудил — теперь сделаешь, что скажу.",
        "Денис?.. Куда ты, блядь, делся?..",
        "Я тебя всё равно найду. Беги в гардеробную!",
        "Блядь, Денис, я иду! Прячься, пока я тебя не нашла!",
        "БЕГИ В ГАРДЕРОБНУЮ, СУКА, И НЕ ПОПАДАЙСЯ МНЕ!",
        "Я ТЕБЕ СЕЙЧАС ЭТОТ ЧАЙНИК В ЖОПУ ЗАСУНУ!",
        "КАКОГО ХУЯ ТЫ ЕЩЁ НЕ СПРЯТАЛСЯ?!",
        "М-м?.. Денис, потише, пожалуйста.",
        "Денис... я всё слышу. Разберись с этим шумом.",
        "Какого хрена ты там делаешь? Ещё звук — и я встану.",
        "Денис... телефон вибрирует. Убери звук, пожалуйста.",
        "Денис, выключи уже вибрацию, я пытаюсь спать.",
        "ДА ЗАТКНИ ТЫ ЭТОТ ЕБУЧИЙ ТЕЛЕФОН, ДЕНИС!",
        "М-м... пылесос сам включился. Останови его.",
        "Денис, этот пылесос уже заебал. Выключи.",
        "ТЫ СОВСЕМ ЕБАНУЛСЯ? КАКОЙ НАХУЙ ПЫЛЕСОС С УТРА?!",
        "Денис... стиралка опять скачет. Поймай её, пожалуйста.",
        "Денис, она сейчас из ванной уедет. Выключи отжим.",
        "ДЕНИС, БЛЯДЬ, УТИХОМИРЬ ЭТУ СТИРАЛКУ!",
        "КАКОГО ХУЯ СТИРАЛКА ЕДЕТ ПО КОРИДОРУ?! БЕГИ ПРЯТАТЬСЯ!",
        "Денис... чайник шумит.",
        "Сними уже чайник, он заебал гудеть.",
        "Денис, выключи уже звук у телека. Я из-за него не сплю.",
        "ДА ЗАТКНИ ТЫ ЭТОТ ЕБУЧИЙ ТЕЛЕК, ДЕНИС! ОН НА ВСЮ КВАРТИРУ ОРЁТ!",
        "ДЕНИС, БЛЯДЬ! Я ТЕБЕ СЕЙЧАС ЭТОТ ТЕЛЕФОН РАЗЪЕБУ!",
        "ЕБАТЬ, ТЫ РЕАЛЬНО НЕ ВЫКЛЮЧИЛ ПЫЛЕСОС?! БЕГИ, СУКА!",
        "КАКОГО ХУЯ ТЕЛЕК ОРЁТ НА ВСЮ КВАРТИРУ?! ЗАТКНИ ЕГО И БЕГИ В ГАРДЕРОБНУЮ!",
        "ДЕНИС, БЛЯДЬ! КАКОГО ХУЯ ЧАЙНИК ОРЁТ?! БЕГИ ПРЯТАТЬСЯ!",
        "ЕБАТЬ, ТЫ ТАМ КУХНЮ РАЗЪЁБЫВАЕШЬ?! БЕГИ, ПОКА Я НЕ ВЫШЛА!",
        "ДЕНИС, СУКА, ЗАТКНИ СОЗВОН И ПРЯЧЬСЯ, Я ВСЁ СЛЫШУ!",
        "КАКОГО ХУЯ, ДЕНИС?! БЕГИ В ГАРДЕРОБНУЮ, БЛЯДЬ!",
        "Разбудил меня — теперь закажи нормальную еду. И сам оплати.",
        "Раз уж не дал поспать — закажи мне лекарства. За свой счёт.",
        "Иди ванную отмой. Хоть какая-то польза от того, что ты меня разбудил.",
        "Раз не спишь — перемой посуду. И попробуй ещё раз меня разбудить.",
        "Я хочу посмотреть японское фестивальное кино. Принеси телевизор, включи его и стой рядом, пока я не усну.",
        "Денис, еда сама себя не закажет. Я жду.",
        "Где лекарства, Денис? Я не забыла.",
        "Ванная всё ещё грязная. Не беси меня второй раз.",
        "Я слышу, что посуда всё ещё в раковине.",
        "Денис, не уходи. Я ещё не уснула.",
        "Где телевизор? Я хочу своё японское фестивальное кино.",
        "Денис, выполни то, что я попросила.",
        "Вот. Не переключай и стой здесь, пока я смотрю.",
        "Денис... кто там звонит? Забери уже заказ.",
        "ДЕНИС, БЛЯДЬ, У ТЕБЯ КУРЬЕР В ДВЕРЬ ДОЛБИТСЯ!",
        "ДА ЗАБЕРИ ТЫ УЖЕ ЭТО МОЛОКО! ОН МЕНЯ СЕЙЧАС РАЗБУДИТ!",
        "ДЕНИС, СУКА! КУРЬЕР МЕНЯ РАЗБУДИЛ! БЕГИ В ГАРДЕРОБНУЮ, ПОКА Я ТЕБЯ НЕ УВИДЕЛА!",
    ],
    "call": [
        "Денис, вы с нами?",
        "Денис, какой у нас сейчас статус?",
        "Денис, можете коротко подсветить?",
        "Денис, у нас всё в работе?",
        "Денис, подтверждаете THE Платёж? Окно двенадцать секунд.",
        "Был THE Платёж, ты не успел. Жди следующий.",
        "Денис?.. Вас не слышно.",
        "ДЕНИС, ВКЛЮЧИТЕ КАМЕРУ",
    ],
    "denis": [
        "Это не воровство.",
        "Да, коллеги, здесь важно синхронизироваться.",
        "Давайте я отдельно уточню и вернусь.",
        "Сейчас на нашей стороне всё в работе.",
        "Предлагаю вынести это в отдельный слот.",
        "THE Платёж подтверждён.",
    ],
    "courier": [
        "Доставка! Молоко привёз!",
        "Доставка! Откройте дверь!",
        "Денис! Заказ с молоком, забирайте!",
        "Я долго ждать не буду!",
    ],
}

CHARACTERS = {
    "rita": {
        "reference_text": VOICE_LINES["rita"][0],
        "instruct": "female, young adult",
        "speed": 0.95,
        "seed": 20260723,
    },
    "call": {
        "reference_text": VOICE_LINES["call"][0],
        "instruct": "male, very low pitch",
        "speed": 0.97,
        "seed": 20260724,
    },
    "denis": {
        "reference_text": VOICE_LINES["denis"][0],
        "instruct": "male, young adult",
        "speed": 1.02,
        "seed": 20260725,
    },
    "courier": {
        "reference_text": VOICE_LINES["courier"][0],
        "instruct": "male, middle-aged, low pitch, russian accent",
        "speed": 1.04,
        "seed": 20260726,
    },
}


def line_id(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def generate(model: OmniVoice, text: str, output: Path, *, speed: float,
             seed: int, instruct: str | None = None,
             reference_audio: Path | None = None,
             reference_text: str | None = None) -> None:
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    audio = model.generate(
        text=text,
        language="ru",
        instruct=instruct,
        ref_audio=str(reference_audio) if reference_audio else None,
        ref_text=reference_text,
        speed=speed,
        num_step=32,
        guidance_scale=2.0,
        denoise=True,
        postprocess_output=True,
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    sf.write(output, audio[0], model.sampling_rate)


def main() -> int:
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    print(f"Loading {MODEL_ID} on {device}...")
    model = OmniVoice.from_pretrained(MODEL_ID, device_map=device, dtype=dtype)
    reference_root = VOICE_ROOT / "_references"
    reference_root.mkdir(parents=True, exist_ok=True)

    # Reuse the manually approved first Rita take when it exists.
    rita_test = VOICE_ROOT / "rita" / "rita_voice_test.wav"
    rita_reference = reference_root / "rita.wav"
    if rita_test.is_file() and not rita_reference.is_file():
        shutil.copy2(rita_test, rita_reference)

    manifest: dict[str, dict[str, str]] = {}
    total = sum(len(lines) for lines in VOICE_LINES.values())
    completed = 0

    for speaker, lines in VOICE_LINES.items():
        profile = CHARACTERS[speaker]
        reference = reference_root / f"{speaker}.wav"
        reference_text = str(profile["reference_text"])
        if not reference.is_file():
            print(f"Creating stable {speaker} reference...")
            generate(
                model,
                reference_text,
                reference,
                speed=float(profile["speed"]),
                seed=int(profile["seed"]),
                instruct=str(profile["instruct"]),
            )

        manifest[speaker] = {}
        for text in lines:
            completed += 1
            output = VOICE_ROOT / speaker / f"{line_id(text)}.wav"
            manifest[speaker][text] = output.relative_to(PROJECT_ROOT).as_posix()
            if output.is_file() and output.stat().st_size > 1024:
                print(f"[{completed:02d}/{total}] cached {speaker}: {text[:52]}")
                continue
            if text == reference_text:
                output.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(reference, output)
            else:
                # Stable per-line seeds vary prosody without changing the cloned identity.
                stable_seed = int(profile["seed"]) + int(line_id(text)[:6], 16)
                speed = float(profile["speed"])
                if text.isupper() and len(text) > 12:
                    speed = min(1.12, speed + 0.08)
                generate(
                    model,
                    text,
                    output,
                    speed=speed,
                    seed=stable_seed,
                    reference_audio=reference,
                    reference_text=reference_text,
                )
            print(f"[{completed:02d}/{total}] generated {speaker}: {text[:52]}")

    manifest_path = VOICE_ROOT / "voice_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Voice bank ready: {total} lines, manifest={manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
