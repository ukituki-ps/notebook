#!/usr/bin/env bash
# stand-reset <stand> — герметичный ре-сид стенда (down -v → up → seed).
# Запускать АГЕНТОМ на docker-хосте ПОСЛЕ аренды и ДО использования:
# каждый прогон должен стартовать с чистого состояния (изоляция и воспроизводимость).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
STANDS="${ROOT}/deploy/stands"
stand="${1:?usage: stand-reset <stand>}"
echo "stand-reset: reset '$stand' (down -v → up → seed)"
exec bash "${STANDS}/stand.sh" reset "$stand"
