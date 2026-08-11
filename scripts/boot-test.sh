#!/usr/bin/env bash
set -euo pipefail

readonly project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly artifact_suffix="-boot-test"
readonly iso_path="build/kernal${artifact_suffix}.iso"
readonly log_path="build/kernal${artifact_suffix}.log"
readonly qemu_status_expected=33

cd "$project_dir"

make iso \
	ARTIFACT_SUFFIX="$artifact_suffix" \
	ODIN_DEFINES=-define:KERNEL_BOOT_TEST=true

set +e
timeout --foreground 10s qemu-system-x86_64 \
	-M q35 \
	-m 128M \
	-cdrom "$iso_path" \
	-boot d \
	-display none \
	-serial stdio \
	-monitor none \
	-no-reboot \
	-device isa-debug-exit,iobase=0xf4,iosize=0x04 \
	>"$log_path" 2>&1
qemu_status=$?
set -e

cat "$log_path"

if ((qemu_status != qemu_status_expected)); then
	echo "boot test: expected QEMU status $qemu_status_expected, got $qemu_status" >&2
	exit 1
fi

if ! grep -q "BOOT TEST PASSED" "$log_path"; then
	echo "boot test: success marker not found" >&2
	exit 1
fi
