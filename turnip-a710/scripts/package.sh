#!/usr/bin/env bash
set -euo pipefail
BASE="${1:-FD725}"
SO="mesa/build-android/src/freedreno/vulkan/libvulkan_freedreno.so"
VER="$(git -C mesa describe --tags --always)"
[[ -s "$SO" ]] || { echo "ERRO: biblioteca não encontrada: $SO" >&2; exit 1; }

mkdir -p out/pkg
cp "$SO" out/pkg/libvulkan_freedreno.so
cat > out/pkg/meta.json <<JSON
{
  "schemaVersion": 1,
  "name": "Turnip A710 experimental ($VER)",
  "description": "Mesa $VER; Adreno 710 associado ao perfil $BASE. Build experimental, requer teste no dispositivo.",
  "author": "GitHub Actions",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "Mesa $VER",
  "minApi": 33,
  "libraryName": "libvulkan_freedreno.so"
}
JSON
(cd out/pkg && zip -9 ../Turnip-A710-$VER.zip libvulkan_freedreno.so meta.json)
sha256sum out/Turnip-A710-$VER.zip | tee out/SHA256SUMS.txt
