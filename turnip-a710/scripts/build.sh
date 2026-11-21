#!/usr/bin/env bash
set -euo pipefail

SDK="${SDK:-33}"
NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-}}"
if [[ -z "$NDK" || ! -d "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin" ]]; then
  echo "ERRO: NDK não encontrado. Defina ANDROID_NDK_LATEST_HOME ou ANDROID_NDK_HOME." >&2
  exit 1
fi

BIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC="$BIN/aarch64-linux-android${SDK}-clang"
CXX="$BIN/aarch64-linux-android${SDK}-clang++"
for tool in "$CC" "$CXX" "$BIN/llvm-ar" "$BIN/llvm-strip" "$BIN/ld.lld"; do
  [[ -x "$tool" ]] || { echo "ERRO: ferramenta do NDK ausente: $tool" >&2; exit 1; }
done

# Segue o cross-file oficial documentado pelo Mesa para Android.
# PKG_CONFIG_LIBDIR vazio impede que dependências Linux do runner sejam
# confundidas com bibliotecas Android.
mkdir -p "$NDK/pkgconfig"
export PATH="$BIN:$PATH"

cat > android-aarch64.txt <<CROSS
[binaries]
ar = '$BIN/llvm-ar'
c = ['ccache', '$CC']
cpp = ['ccache', '$CXX', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$BIN/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$NDK/pkgconfig', '/usr/bin/pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
CROSS

cd mesa
meson setup build-android --cross-file ../android-aarch64.txt \
  --buildtype=release -Dstrip=true -Db_lto="${LTO:-false}" \
  -Dplatforms=android -Dplatform-sdk-version="$SDK" -Dandroid-stub=true \
  -Dandroid-libbacktrace=disabled -Degl=disabled \
  -Dgallium-drivers=[] -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl

meson compile -C build-android
SO="build-android/src/freedreno/vulkan/libvulkan_freedreno.so"
[[ -s "$SO" ]] || { echo "ERRO: build terminou sem gerar $SO" >&2; exit 1; }
file "$SO"
