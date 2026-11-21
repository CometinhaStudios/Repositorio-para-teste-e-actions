#!/usr/bin/env python3
"""Add the experimental Adreno 710 chip ID to an existing Mesa GPU profile."""
import re
import sys
from pathlib import Path

if len(sys.argv) < 2:
    raise SystemExit("Uso: add_a710.py <pasta-mesa> [GPU-base]")

root = Path(sys.argv[1])
base = sys.argv[2] if len(sys.argv) > 2 else "FD725"
path = root / "src/freedreno/common/freedreno_devices.py"
if not path.is_file():
    raise SystemExit(f"ERRO: arquivo não encontrado: {path}")

src = path.read_text()
if "0x07010000" in src or 'name="FD710"' in src:
    print("FD710 já existe no Mesa; nenhuma alteração necessária.")
    raise SystemExit(0)

lines = src.splitlines()
matches = [i for i, line in enumerate(lines) if f'name="{base}"' in line]
if not matches:
    raise SystemExit(f"ERRO: perfil base {base} não encontrado em {path}")

# Insere o ID na mesma lista de IDs do perfil base, antes do fechamento da lista.
idx = matches[0]
if "GPUId(" not in lines[idx]:
    raise SystemExit(f"ERRO: linha inesperada para {base}: {lines[idx]!r}")
indent = re.match(r"\s*", lines[idx]).group(0)
lines.insert(idx + 1, f'{indent}GPUId(chip_id=0x07010000, name="FD710"),')

updated = "\n".join(lines) + "\n"
# Confirma que a nova GPUId ficou dentro do bloco add_gpus que contém o perfil base.
block_start = max((i for i in range(idx + 1) if "add_gpus([" in lines[i]), default=-1)
block_end = next((i for i in range(idx + 1, len(lines)) if "], A" in lines[i]), -1)
if block_start < 0 or block_end < 0 or not (block_start < idx + 1 < block_end):
    raise SystemExit("ERRO: não foi possível confirmar o bloco add_gpus do perfil base.")

path.write_text(updated)
print(f"OK: FD710 (0x07010000) associado ao perfil {base}.")
