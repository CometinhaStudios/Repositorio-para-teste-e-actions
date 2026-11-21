# Turnip Perf + OneUI 8G2 — crash-fix baseline

This workflow rebuilds the Mesa Turnip Vulkan driver for Snapdragon 8 Gen 2 / Adreno 740.

## Changes based on Claude's v3 kit
- Keeps static libc++ linkage and refuses to package the library if ELF needs `libc++_shared.so`.
- Removes the old unsafe rewrite of `buffer_handle_t` from `const native_handle_t *` to `void *`.
- Uses a clean Meson setup for fresh GitHub Actions runners and reconfigure only when a build directory already exists.
- Uses Android API 36 consistently in the compiler target and Meson platform setting.
- Starts with experimental performance patches disabled. Enable them one at a time only after the baseline driver is stable.
- Verifies that the output is an AArch64 ELF before packaging.

## Build
GitHub Actions runs on pushes to main or manually from Actions. Artifact:
`turnip-perf-oneui-8g2-stable-baseline`.

## Important
A successful compile and absence of `libc++_shared.so` do not prove runtime compatibility. Test the baseline first on the intended Snapdragon 8 Gen 2 Samsung One UI device. If it still crashes, collect the emulator's Vulkan/driver log and Android tombstone/logcat; do not enable the experimental patches yet.
