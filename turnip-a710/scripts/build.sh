#!/usr/bin/env bash
set -euo pipefail

SDK="${SDK:-33}"
NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-}}"
if [[ -z "$NDK" || ! -d "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin" ]]; then
  echo "ERRO: NDK não encontrado. Defina ANDROID_NDK_LATEST_HOME ou ANDROID_NDK_HOME." >&2
  exit 1
fi

BIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
CC="$BIN/aarch64-linux-android${SDK}-clang"
CXX="$BIN/aarch64-linux-android${SDK}-clang++"
for tool in "$CC" "$CXX" "$BIN/llvm-ar" "$BIN/llvm-strip" "$BIN/ld.lld"; do
  [[ -x "$tool" ]] || { echo "ERRO: ferramenta do NDK ausente: $tool" >&2; exit 1; }
done

cat > android-aarch64.txt <<CROSS
[binaries]
ar = '$BIN/llvm-ar'
c = '$CC'
cpp = '$CXX'
c_ld = '$BIN/ld.lld'
cpp_ld = '$BIN/ld.lld'
strip = '$BIN/llvm-strip'
pkg-config = '/usr/bin/pkg-config'

[properties]
sys_root = '$SYSROOT'
pkg_config_libdir = [
  '$SYSROOT/usr/lib/aarch64-linux-android/$SDK/pkgconfig',
  '$SYSROOT/usr/share/pkgconfig'
]

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
  -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dfreedreno-kmds=kgsl \
  -Dvulkan-beta=true -Degl=disabled -Dandroid-libbacktrace=disabled \
  --force-fallback-for=zlib,expat
ninja -C build-android src/freedreno/vulkan/libvulkan_freedreno.so
