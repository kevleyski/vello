#!/usr/bin/env bash
#
# kjsl_build.sh — build, test, and demo Vello
#
# ----------------------------------------------------------------------------
# What is Vello?
# ----------------------------------------------------------------------------
# Vello is a 2D vector graphics rendering engine written in Rust, built around
# GPU compute (a Linebender project, formerly "piet-gpu"). It draws shapes,
# strokes, images, gradients, text, clips, and blends — the same primitives
# that power SVG and the browser <canvas> — using a PostScript-inspired API.
#
# Its trick: where traditional renderers (Skia, Cairo) do sorting/clipping on
# the CPU or via intermediate textures, Vello uses prefix-sum algorithms to
# parallelize that work onto the GPU with minimal temporary buffers, via wgpu
# (Metal / Vulkan / DX12 / WebGPU). It is the rendering backend for the Xilem
# Rust GUI toolkit. Status: alpha.
# ----------------------------------------------------------------------------

set -euo pipefail

# Always run from the repo root (the directory this script lives in).
cd "$(dirname "$0")"

# ANSI colours for readable section headers.
BOLD="\033[1m"; GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; RESET="\033[0m"

section() { echo -e "\n${BOLD}${CYAN}==> $*${RESET}"; }
note()    { echo -e "${YELLOW}$*${RESET}"; }

# Allow skipping the interactive/web demos in headless/CI environments:
#   RUN_INTERACTIVE=0 ./kjsl_build.sh   # skip the winit window
#   RUN_WASM=1        ./kjsl_build.sh   # also build the WebGPU demo
RUN_INTERACTIVE="${RUN_INTERACTIVE:-1}"
RUN_WASM="${RUN_WASM:-0}"

section "Toolchain"
cargo --version
rustc --version

# ----------------------------------------------------------------------------
# Tests
# ----------------------------------------------------------------------------
tests() {
  section "Tests: CPU renderer (vello_common + vello_cpu — no GPU needed)"
  cargo test -p vello_common -p vello_cpu

  section "Tests: core GPU renderer (vello + vello_encoding)"
  cargo test -p vello -p vello_encoding

  section "Tests: GPU snapshot / integration (vello_tests)"
  cargo test -p vello_tests

  section "Tests: hybrid + sparse renderers (vello_hybrid + vello_sparse_tests)"
  cargo test -p vello_hybrid -p vello_sparse_tests
}

# ----------------------------------------------------------------------------
# Demos
# ----------------------------------------------------------------------------

# Headless render of a named scene to PNG — works without a display, so it is
# the default demo. Output lands in examples/headless/outputs/.
section "Demo: headless render of 'mmark' scene to PNG"
cargo run -p headless --release -- --test-scenes -s mmark -x 1024 -y 1024
note "PNG written under examples/headless/outputs/"

# Interactive window with all test scenes (best demo). Needs a display, so it
# is opt-out via RUN_INTERACTIVE=0.
if [ "${RUN_INTERACTIVE}" = "1" ]; then
  section "Demo: interactive window with all test scenes (close the window to continue)"
  cargo run -p with_winit -- --test-scenes
else
  note "Skipping interactive winit demo (RUN_INTERACTIVE=0)."
  note "Run it manually with: cargo run -p with_winit -- --test-scenes"
fi

# Web/WebGPU build of the winit demo. Opt-in via RUN_WASM=1 (needs the
# wasm32 target and starts a local web server).
if [ "${RUN_WASM}" = "1" ]; then
  section "Demo: Web/WebGPU build of the winit demo"
  rustup target add wasm32-unknown-unknown
  cargo run_wasm -p with_winit --bin with_winit_bin
else
  note "Skipping Web/WebGPU demo (set RUN_WASM=1 to enable)."
  note "Run it manually with: cargo run_wasm -p with_winit --bin with_winit_bin"
fi

section "Done"
echo -e "${GREEN}All requested tests and demos completed.${RESET}"
