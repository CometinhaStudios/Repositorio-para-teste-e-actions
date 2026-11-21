#!/usr/bin/env bash
set -euo pipefail

green='\033[0;32m'; red='\033[0;31m'; nocolor='\033[0m'
workdir="$(pwd)/turnip_workdir"
ndkver="android-ndk-r29"
ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"
sdkver="34"
mesasrc="https://gitlab.freedesktop.org/mesa/mesa"
srcfolder="mesa"

check_deps() {
  local missing=0
  for cmd in git meson ninja patchelf unzip curl pip3 flex bison zip glslangValidator python3 ccache readelf; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo -e "${green} - $cmd found${nocolor}"
    else
      echo -e "${red} - $cmd missing${nocolor}"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "Install missing dependencies before building."
    exit 1
  fi
  python3 -m pip install --break-system-packages mako
}

prepare_workdir() {
  mkdir -p "$workdir"
  cd "$workdir"
  if [ "${SKIP_SOURCE_DOWNLOAD:-0}" = "1" ]; then
    test -d "$srcfolder/.git" || { echo "Mesa source tree missing"; exit 1; }
    git -C "$srcfolder" checkout .
    return
  fi
  curl -fL "https://dl.google.com/android/repository/$ndkver-linux.zip" -o "$ndkver-linux.zip"
  unzip -q -o "$ndkver-linux.zip"
  if [ -d "$srcfolder/.git" ]; then rm -rf "$srcfolder"; fi
  git clone --depth=1 -b main "$mesasrc" "$srcfolder"
}

build_lib_for_android() {
  cd "$workdir/$srcfolder"
  echo "==== Building Mesa Turnip for Adreno 740 / Snapdragon 8 Gen 2 ===="

  if [ -f ../../patches/common/apply_common.sh ]; then
    bash ../../patches/common/apply_common.sh . || { echo "Common patches failed"; exit 1; }
  else
    echo "[kit] No Banners common patch set; continuing with A740-specific patch."
  fi

  python3 ../../patches/8g2_oneui.py
  PERF_ARGS=()
  [ "${OPT_GCM:-0}" = "1" ] && PERF_ARGS+=(--gcm)
  [ "${OPT_ZELDA:-0}" = "1" ] && PERF_ARGS+=(--zelda)
  [ "${OPT_SUBALLOC:-0}" = "1" ] && PERF_ARGS+=(--suballoc)
  [ "${OPT_CACHE:-0}" = "1" ] && PERF_ARGS+=(--cache)
  python3 ../../patches/balemuni_style_perf.py "${PERF_ARGS[@]}"
  cp -f balemuni_perf_report.txt "$workdir/balemuni_perf_report.txt"

  # Do NOT change buffer_handle_t to void*: that breaks Android gralloc const correctness.
  # Keep only the narrowly-scoped NDK r29 compatibility casts from the v3 kit.
  sed -i 's/, hnd->handle/, (void *)hnd->handle/g' src/util/u_gralloc/u_gralloc_fallback.c || true
  sed -i -E 's/([a-z_]+)->handle->/((const native_handle_t *)\1->handle)->/g' src/vulkan/runtime/vk_android.c || true

  mkdir -p "$workdir/bin"
  ln -sf "$ndk/clang" "$workdir/bin/cc"
  ln -sf "$ndk/clang++" "$workdir/bin/c++"
  export PATH="$workdir/bin:$ndk:$PATH"
  export CC=clang CXX=clang++ AR=llvm-ar RANLIB=llvm-ranlib STRIP=llvm-strip
  export OBJDUMP=llvm-objdump OBJCOPY=llvm-objcopy
  export LDFLAGS="-fuse-ld=lld -flto=thin"
  export CFLAGS="-D__ANDROID__ -O3 -fno-plt -flto=thin -Wno-error -Wno-deprecated-declarations -Wno-incompatible-pointer-types-discards-qualifiers -Wno-incompatible-pointer-types"
  export CXXFLAGS="$CFLAGS"

  GITHASH="$(git rev-parse --short HEAD)"
  cat > android-aarch64.txt <<EOF
[binaries]
ar = '$ndk/llvm-ar'
c = ['ccache', '$ndk/aarch64-linux-android$sdkver-clang']
cpp = ['ccache', '$ndk/aarch64-linux-android$sdkver-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '--start-no-unused-arguments', '-static-libstdc++', '--end-no-unused-arguments']
c_ld = '$ndk/ld.lld'
cpp_ld = '$ndk/ld.lld'
strip = '$ndk/llvm-strip'
pkg-config = ['env', 'PKG_CONFIG_LIBDIR=$ndk/pkg-config', '/usr/bin/pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'

[built-in options]
cpp_link_args = ['-static-libstdc++']
EOF

  cat > native.txt <<EOF
[build_machine]
c = ['ccache', 'clang']
cpp = ['ccache', 'clang++']
ar = 'llvm-ar'
strip = 'llvm-strip'
c_ld = 'ld.lld'
cpp_ld = 'ld.lld'
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

  MESON_ARGS=(
    --cross-file android-aarch64.txt
    --native-file native.txt
    --prefix "/tmp/turnip-$GITHASH"
    -Dbuildtype=release -Db_ndebug=true -Dstrip=true
    -Dplatforms=android -Dvideo-codecs=
    -Dplatform-sdk-version="$sdkver"
    -Dandroid-stub=true -Dgallium-drivers=
    -Dvulkan-drivers=freedreno -Dvulkan-beta=true
    -Dfreedreno-kmds=kgsl -Degl=disabled
    -Dandroid-libbacktrace=disabled
  )

  if [ -d build-android-aarch64/meson-private ]; then
    meson setup build-android-aarch64 "${MESON_ARGS[@]}" --reconfigure
  else
    meson setup build-android-aarch64 "${MESON_ARGS[@]}"
  fi

  ninja -C build-android-aarch64 install
  LIB="/tmp/turnip-$GITHASH/lib/libvulkan_freedreno.so"
  test -s "$LIB" || { echo "libvulkan_freedreno.so missing or empty"; exit 1; }

  echo "Checking ELF dependencies:"
  readelf -d "$LIB" | grep NEEDED || true
  if readelf -d "$LIB" | grep -q "libc++_shared.so"; then
    echo -e "${red}FATAL: libc++_shared.so dependency found; refusing to package a crashing driver.${nocolor}"
    exit 1
  fi
  if readelf -h "$LIB" | grep -q "AArch64"; then
    echo "ELF architecture verified: AArch64"
  else
    echo "FATAL: output is not AArch64"
    exit 1
  fi

  mkdir -p "$workdir/package"
  cp "$LIB" "$workdir/package/libvulkan_freedreno.so"
  cat > "$workdir/package/meta.json" <<EOF
{
  "schemaVersion": 1,
  "name": "Turnip Perf + OneUI 8G2 $GITHASH",
  "description": "Mesa $GITHASH, Adreno 740 OneUI UBWC fix, static libc++ linkage. Optional performance tweaks disabled for baseline stability.",
  "author": "CometinhaStudios / Mesa",
  "packageVersion": "perf-oneui-$GITHASH",
  "vendor": "Mesa",
  "driverVersion": "Mesa $GITHASH",
  "minApi": 33,
  "libraryName": "libvulkan_freedreno.so"
}
EOF
  ZIP="$workdir/Turnip-Perf-OneUI-8G2-$GITHASH.zip"
  (cd "$workdir/package" && zip -q -FS "$ZIP" libvulkan_freedreno.so meta.json)
  test -s "$ZIP"
  echo -e "${green}Build completed: $ZIP${nocolor}"
}

echo "====== Turnip Perf + OneUI 8G2 baseline build ======"
check_deps
prepare_workdir
build_lib_for_android
