"""Validate direct audio inputs and keep their contents out of persistence."""
import base64
import binascii
from typing import Any

from fastapi import HTTPException

MAX_AUDIO_BYTES = 8 * 1024 * 1024
AUDIO_FORMATS = {'wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac', 'webm'}


class AudioInputError(ValueError):
    """Safe audio errors that may be shown to the user without payload details."""


def prepare_attachments(items: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    metadata, audio = [], []
    total = 0
    for item in items:
        if 'audio_base64' not in item:
            if str(item.get('mime_type', '')).startswith('audio/'):
                raise HTTPException(422, 'Audio attachment is missing its audio data.')
            metadata.append(item)
            continue
        encoded = item['audio_base64']
        fmt = item.get('audio_format')
        if not isinstance(fmt, str) or fmt not in AUDIO_FORMATS or not isinstance(encoded, str):
            raise HTTPException(422, 'Unsupported audio format.')
        if len(encoded) > ((MAX_AUDIO_BYTES + 2) // 3) * 4:
            raise HTTPException(413, 'Audio attachments must total at most 8 MB.')
        try:
            raw = base64.b64decode(encoded, validate=True)
        except (ValueError, binascii.Error):
            raise HTTPException(422, 'Invalid audio encoding.') from None
        total += len(raw)
        if total > MAX_AUDIO_BYTES:
            raise HTTPException(413, 'Audio attachments must total at most 8 MB.')
        if not raw:
            raise HTTPException(422, 'Audio attachment is empty.')
        safe = {key: item[key] for key in ('name', 'mime_type') if key in item}
        safe.update(size_bytes=len(raw), audio_format=fmt)
        metadata.append(safe)
        audio.append({**safe, 'audio_base64': encoded})
    if len(audio) > 4:
        raise HTTPException(422, 'At most four audio attachments are supported.')
    return metadata, audio
