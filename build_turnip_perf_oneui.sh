#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
WORK="$ROOT/turnip_workdir"
NDKVER="android-ndk-r29"
NDK="$WORK/$NDKVER/toolchains/llvm/prebuilt/linux-x86_64/bin"
mkdir -p "$WORK"
for cmd in git meson ninja unzip curl pip3 flex bison zip glslangValidator python3; do command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd"; exit 1; }; done
pip3 install --break-system-packages mako
cd "$WORK"
curl -fL "https://dl.google.com/android/repository/$NDKVER-linux.zip" -o "$NDKVER-linux.zip"
unzip -q "$NDKVER-linux.zip"
git clone --depth=1 -b main https://gitlab.freedesktop.org/mesa/mesa mesa
cd "$WORK/mesa"
python3 "$ROOT/patches/8g2_oneui.py"
ARGS=()
[[ "${OPT_GCM:-1}" == 1 ]] && ARGS+=(--gcm)
[[ "${OPT_ZELDA:-1}" == 1 ]] && ARGS+=(--zelda)
[[ "${OPT_SUBALLOC:-1}" == 1 ]] && ARGS+=(--suballoc)
[[ "${OPT_CACHE:-1}" == 1 ]] && ARGS+=(--cache)
python3 "$ROOT/patches/balemuni_style_perf.py" "${ARGS[@]}"
cp balemuni_perf_report.txt "$WORK/"
mkdir -p "$WORK/bin"
ln -sf "$NDK/clang" "$WORK/bin/cc"
ln -sf "$NDK/clang++" "$WORK/bin/c++"
export PATH="$WORK/bin:$NDK:$PATH" CC=clang CXX=clang++ AR=llvm-ar RANLIB=llvm-ranlib STRIP=llvm-strip
export CFLAGS="-D__ANDROID__ -O3 -flto=thin -Wno-error" CXXFLAGS="-D__ANDROID__ -O3 -flto=thin -Wno-error" LDFLAGS="-fuse-ld=lld -flto=thin"
cat > android-aarch64.txt <<EOF
[binaries]
ar = '$NDK/llvm-ar'
c = ['$NDK/aarch64-linux-android34-clang']
cpp = ['$NDK/aarch64-linux-android34-clang++']
c_ld = '$NDK/ld.lld'
cpp_ld = '$NDK/ld.lld'
strip = '$NDK/llvm-strip'
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
[built-in options]
c_args = ['-mtune=cortex-x3']
cpp_args = ['-mtune=cortex-x3']
EOF
cat > native.txt <<EOF
[build_machine]
c = 'clang'
cpp = 'clang++'
ar = 'llvm-ar'
strip = 'llvm-strip'
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
HASH="$(git rev-parse --short HEAD)"
meson setup build-android-aarch64 --cross-file android-aarch64.txt --native-file native.txt --prefix "/tmp/turnip-$HASH" -Dbuildtype=release -Db_ndebug=true -Dstrip=true -Dplatforms=android -Dvideo-codecs= -Dplatform-sdk-version=36 -Dandroid-stub=true -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dvulkan-beta=true -Dfreedreno-kmds=kgsl -Degl=disabled -Dandroid-libbacktrace=disabled
ninja -C build-android-aarch64 install
LIB="/tmp/turnip-$HASH/lib/libvulkan_freedreno.so"
test -f "$LIB"
mkdir -p "$WORK/package"
cp "$LIB" "$WORK/package/"
printf '{"schemaVersion":1,"name":"Turnip Perf OneUI 8G2 %s","description":"Custom Mesa Turnip build for Adreno 740 One UI validation","author":"CometinhaStudios","packageVersion":"perf-oneui-%s","vendor":"Mesa","driverVersion":"Mesa %s","minApi":33,"libraryName":"libvulkan_freedreno.so"}\n' "$HASH" "$HASH" "$HASH" > "$WORK/package/meta.json"
(cd "$WORK/package" && zip -q "$WORK/Turnip-Perf-OneUI-8G2-$HASH.zip" libvulkan_freedreno.so meta.json)
echo "Build complete: $WORK/Turnip-Perf-OneUI-8G2-$HASH.zip"
