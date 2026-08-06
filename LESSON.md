# Building a Toy Kernel with Odin

This is our shared lesson plan. We will use it to choose the next small step,
record what we learned, and avoid skipping the basics.

The directory is named `kernal`, but the correct spelling is **kernel**.

## Goal

Build a small x86-64 kernel in Odin that boots in QEMU, reports failures,
manages memory, handles interrupts, runs simple tasks, enters user mode, and can
eventually exchange a named task with another machine.

This is not a promise to build a complete general-purpose operating system. It
is a course for learning enough to design one with care.

## Fixed scope

- Architecture: x86-64
- First machine: QEMU only
- Bootloader: Limine; we will not write a bootloader first
- Kernel style: small monolithic kernel
- Main language: Odin
- Assembly: small, inspected boundary stubs only
- First and main output: a 16550A serial port
- First scheduler: cooperative, then timer-driven
- Network path: an optional branch after core kernel work

There is no single calling convention for the whole kernel:

- Limine and assembly entry boundary: System V AMD64, without FP/SIMD values
- Internal Odin calls: the ABI produced by our pinned Odin compiler
- Interrupt and system-call frames: layouts defined by x86-64
- Exported machine entry: a foreign/contextless Odin procedure, not an ordinary
  Odin procedure with an implicit `context`

We will pin exact Odin, Limine, and Limine protocol revisions before producing
the first boot image. Odin is pre-1.0 and the Limine protocol changes.

## Size rule

Each milestone introduces:

1. **One new invariant** we want to make true.
2. **One observable result** that shows whether it is true.

If a milestone needs several unrelated changes before anything can be seen, it
is too large and must be split again.

## Session loop

For each milestone:

1. Explain the idea in plain terms.
2. Predict the result before running anything.
3. Make the smallest change that tests the prediction.
4. Inspect the result with tools instead of guessing.
5. Test success and deliberate failure separately.
6. Explain the result back in a few sentences.
7. Mark the milestone complete and add a short learning note.

The guide should not paste a finished subsystem. The learner should understand
each change before the next one is added.

## Project rules

- Keep the program or kernel runnable after each milestone.
- Prefer visible behavior over hidden framework code.
- Do not add a feature until we can state which problem it solves.
- Use Git before the first freestanding change.
- Inspect binaries, disassembly, and machine state when useful.
- Run QEMU tests with timeouts and machine-readable exit results.
- Test real hardware only after the QEMU design is sound.
- Use fixed-width integers at hardware and file-format boundaries.
- Label addresses as physical or virtual.
- Check address, size, and alignment arithmetic for overflow.
- Do not allocate until an allocator exists and has tests.
- Keep panic and interrupt paths able to run without allocation.
- Do not enable interrupts until logging and exception handling work.
- Do not use FP/SIMD in kernel tasks until its state is saved and restored.
- Record surprising failures under **Learning notes**.

## Current baseline

`main.odin` is a normal Linux user-space program:

```odin
package main

import "core:fmt"

main :: proc() {
	fmt.println("Hello, world!")
}
```

Linux loads this program, gives it memory, and provides the output facilities
used by `core:fmt`. It is not a kernel.

Installed:

- Odin `dev-2026-07:301c287de`
- OLS and odinfmt
- Clang, LLD, GDB, and Make

Needed later:

- QEMU x86 system emulator
- xorriso or another image tool
- A pinned Limine binary release and protocol revision

We install tools only when a milestone needs them.

## Progress

States are `not started`, `in progress`, `complete`, and `blocked`.

| Phase | Purpose | State |
|---|---|---|
| A | Hosted foundations | in progress |
| B | Binary and freestanding foundations | in progress |
| C | First boot and diagnostics | in progress |
| D | CPU exceptions | not started |
| E | Memory ownership | not started |
| F | Interrupts and kernel tasks | not started |
| G | User/kernel boundary | not started |
| H | Optional network and distributed task | not started |

Current milestone: **C1**.

---

## Phase A: Hosted foundations

These exercises run under Linux. They let us learn Odin and machine concepts
with guardrails.

### A0 — What runs Hello World?

- [x] Build and run the current program.
- [x] Check its exit status.
- [ ] Inspect it with `file`, `ldd`, `readelf`, and `nm`.
- [ ] Identify source, compiler, ELF file, loader, process, and kernel.

**Invariant:** we can account for every layer needed to run this program.

**Observable result:** we can find its ELF entry and explain why that is not
the same thing as a bare-metal kernel entry.

### A1 — Shell, Make, tests, and Git readiness

- [ ] Explain working directories, paths, exit codes, and pipes.
- [ ] Explain each current Make target.
- [ ] Add and run one small Odin test.
- [ ] Create a Git checkpoint before later build changes.

**Invariant:** failed commands stop the build and known-good work is recoverable.

**Observable result:** one passing and one deliberate failing test produce the
expected exit codes.

### A2 — Bits, hexadecimal, overflow, and byte order

- [ ] Convert small values between binary, hexadecimal, and decimal.
- [ ] Set, clear, and test bits with masks.
- [ ] Observe signed and unsigned overflow behavior.
- [ ] Print the memory bytes of a multi-byte integer.

**Invariant:** register-like values are changed without damaging unrelated bits.

**Observable result:** tests decode a made-up 32-bit register and show its
little-endian bytes.

### A3 — Odin values and memory layout

- [ ] Compare fixed integers, arrays, slices, strings, structs, enums, and bit sets.
- [ ] Inspect size, alignment, padding, and field offsets.
- [ ] Learn the difference between owned data and a view of data.

**Invariant:** hardware-facing records have an intentional, checked layout.

**Observable result:** predicted and measured struct offsets agree.

### A4 — Pointers, addresses, and lifetime

- [ ] Distinguish a value, pointer, and numeric address.
- [ ] Locate stack, static, and heap values.
- [ ] Use GDB to inspect a local value and its address.
- [ ] Demonstrate one invalid-lifetime bug in a safe, hosted experiment.

**Invariant:** every used pointer refers to live storage with suitable alignment.

**Observable result:** a pointer diagram matches what GDB shows.

### A5 — x86-64 registers, assembly, and the call stack

- [ ] Read a small compiler-generated assembly procedure.
- [ ] Identify instruction pointer, stack pointer, arguments, and return value.
- [ ] Observe stack growth and alignment in GDB.
- [ ] Learn caller-saved and callee-saved registers at a high level.

**Invariant:** a call preserves the machine state promised by its ABI.

**Observable result:** we can follow one call and return in assembly.

### A6 — Odin procedures, context, allocators, and errors

- [ ] Compare Odin and foreign procedure declarations.
- [ ] Inspect Odin's implicit `context` behavior.
- [ ] Use an explicit allocator in a hosted exercise.
- [ ] Use multiple returns for explicit error handling.

**Invariant:** code states which outside services it needs.

**Observable result:** the same small procedure succeeds with one allocator and
fails in a controlled way with another.

---

## Phase B: Binary and freestanding foundations

### B0 — CPU and boot-chain model

- [ ] Draw firmware → bootloader → kernel → user program.
- [ ] Label privilege levels, stack ownership, and address spaces.
- [ ] List what Limine prepares and what the kernel must replace or own.

**Invariant:** responsibility at each boot boundary is explicit.

**Observable result:** we can explain why a bootloader is useful without
mistaking it for part of our kernel.

### B1 — Object files, ELF sections, symbols, and relocations

- [ ] Compile a small hosted object file.
- [ ] Inspect code, read-only data, data, and zero-filled data sections.
- [ ] Find symbols and relocations with `readelf`, `objdump`, and `nm`.

**Invariant:** every external reference is either resolved later or expected.

**Observable result:** we can point to a symbol and its relocation.

### B2 — External linking and a linker script

- [ ] Link a tiny object with `ld.lld`.
- [ ] Control its entry and segment addresses with a linker script.
- [ ] Inspect the resulting ELF program headers.

**Invariant:** the linked image has the entry and load layout we specified.

**Observable result:** `readelf` confirms the predicted entry and segments.

### B3 — QEMU and GDB on a known image

- [ ] Install QEMU and the image tools.
- [ ] Pin a QEMU machine type and command line.
- [ ] Start a known image paused with `-s -S`.
- [ ] Connect GDB and inspect registers.

**Invariant:** we can distinguish build failure, boot failure, and code failure.

**Observable result:** GDB single-steps a known guest instruction.

### B4 — A freestanding Odin object

The expected path for the pinned compiler is object generation followed by an
external link, not direct freestanding executable linking.

- [x] Start from `-target:freestanding_amd64_sysv` and `-build-mode:obj`.
- [ ] Evaluate `-disable-red-zone`, `-no-thread-local`, `-no-crt`,
  `-use-single-module`, and a nil or panic default allocator.
- [x] Avoid host-dependent `core:fmt` and `core:os` imports.
- [x] Export a contextless foreign entry procedure.
- [ ] Inspect all sections, symbols, relocations, and unresolved helpers.
- [ ] Check for TLS, `.odinti`, and unexpected FP/SIMD instructions.

Freestanding does **not** mean that Odin emits no runtime support. Compiler
helpers, panic behavior, type information, and allocation assumptions must be
inspected rather than wished away. A soft-float target feature is a candidate,
not a substitute for checking disassembly.

**Invariant:** the object has no unexplained host or runtime dependency.

**Observable result:** a written inventory accounts for every unresolved symbol
and relevant section.

### B5 — A linked kernel ELF that has not booted yet

- [x] Link the Odin object with `ld.lld` and our linker script.
- [x] Keep an unstripped ELF for GDB.
- [x] Verify entry, segments, permissions, symbols, and remaining relocations.

**Invariant:** the kernel ELF is internally consistent before adding a boot image.

**Observable result:** all static inspection checks pass from a clean build.

---

## Phase C: First boot and diagnostics

### C0 — Pin Limine and reach the entry breakpoint

- [ ] Pin Limine and the protocol revision.
- [ ] Use current request start/end markers and base-revision declarations.
- [x] Build the smallest boot image.
- [x] Boot with no output requirement.
- [x] Stop at the Odin entry in GDB.

**Invariant:** Limine reaches our exact entry using the expected ABI.

**Observable result:** GDB stops at the source symbol in the unstripped ELF.

### C1 — Port I/O and UART initialization

`-serial stdio` connects QEMU's device to the host terminal; it does not
initialize the emulated serial hardware.

- [ ] Learn x86 port-I/O instructions and make tiny wrappers.
- [ ] Initialize the 16550A at COM1 (`0x3f8`).
- [ ] Poll status instead of assuming the device is ready.
- [ ] Perform a loopback check before normal output.

**Invariant:** serial writes happen only after the UART reports readiness.

**Observable result:** one known byte appears with `-serial stdio -monitor none`.

### C2 — Non-allocating kernel logging and panic

- [ ] Print characters, strings, and hexadecimal integers.
- [ ] Add a panic path that reports a location and halts.
- [ ] Give QEMU tests a timeout and controlled exit path where practical.

**Invariant:** diagnostics do not allocate or return from fatal failures.

**Observable result:** a separate deliberate-panic boot prints its location and
halts predictably.

### C3 — Limine boot contract and ownership

- [ ] Check that the requested base revision is supported.
- [ ] Request and record HHDM rather than assuming a fixed offset.
- [ ] Label response pointers and payload addresses as physical or virtual.
- [ ] Learn the lifetime of response data, the initial stack, GDT, and page tables.
- [ ] Plan copies and replacements before reclaiming bootloader memory.

**Invariant:** no bootloader-owned storage is reclaimed while we still use it.

**Observable result:** an ownership table names the owner and lifetime of every
piece of handoff state we retain.

---

## Phase D: CPU exceptions

### D0 — Install an owned GDT

- [ ] Learn segment descriptors in x86-64 long mode.
- [ ] Load a minimal kernel GDT that lives in kernel-owned memory.

**Invariant:** descriptor state no longer depends on bootloader-reclaimable data.

**Observable result:** execution continues after loading and verifying the GDT.

### D1 — One IDT gate and `INT3`

- [ ] Define one IDT entry.
- [ ] Enter through a small assembly stub.
- [ ] Save enough state to print vector and instruction pointer.
- [ ] Return with `IRETQ` only where return is valid.

**Invariant:** one known trap reaches one known handler with an understood frame.

**Observable result:** `INT3` reports the expected vector and address.

### D2 — Normalize exception frames

- [ ] Handle vectors with and without CPU-pushed error codes.
- [ ] Add a fatal `UD2` test in a separate boot.
- [ ] Add a page-fault report including its fault address and error bits.

Do not assume an Odin division expression produces CPU vector 0; compiler checks
may emit `UD2`. Use controlled instructions and inspect generated code.

**Invariant:** handlers receive one documented frame shape.

**Observable result:** `UD2` and a page fault report the expected distinct state.

### D3 — TSS and an emergency exception stack

- [ ] Add an owned TSS.
- [ ] Configure an IST stack for double faults.
- [ ] Add guard space around critical stacks later when paging is owned.

**Invariant:** a damaged normal stack does not remove the final diagnostic path.

**Observable result:** the double-fault path uses the expected emergency stack.

---

## Phase E: Memory ownership

### E0 — Validate the Limine memory map

- [ ] Parse without allocating.
- [ ] Validate ordering, overflow, alignment, overlap rules, and type values.
- [ ] Boot with several QEMU RAM sizes.
- [ ] Compare invariants, not exact addresses across boots.

**Invariant:** malformed or impossible ranges are rejected before use.

**Observable result:** summaries remain internally consistent at each RAM size.

### E1 — Monotonic physical-page allocation

- [ ] Seed only from Limine `USABLE` ranges.
- [ ] Initially exclude all bootloader-reclaimable memory.
- [ ] Allocate pages without supporting free.

**Invariant:** each allocated page is aligned, usable, and never returned twice.

**Observable result:** a host-testable model and QEMU run satisfy the invariant.

### E2 — Free and reuse physical pages

- [ ] Add multiple usable ranges.
- [ ] Add free and reuse.
- [ ] Detect double-free and freeing an unknown page.

**Invariant:** allocator ownership changes exactly once per valid operation.

**Observable result:** deliberate duplicate and invalid frees fail predictably.

### E3 — Read-only virtual-address translation

- [ ] Decode canonical x86-64 virtual addresses.
- [ ] Walk current page tables without modifying them.
- [ ] Translate one known kernel symbol.

**Invariant:** translation observes existing mappings without taking ownership.

**Observable result:** the walk agrees with GDB or QEMU's view.

### E4 — Build and switch to owned page tables

- [ ] Build new tables from allocated pages.
- [ ] Map the kernel and required handoff state.
- [ ] Switch `CR3` once, with a rollback/debug plan.

Do not edit Limine's undefined-layout tables in place.

**Invariant:** every mapping needed after `CR3` changes exists in owned tables.

**Observable result:** serial output continues after the switch.

### E5 — Map one protected page

- [ ] Map one read/write, non-executable page.
- [ ] Inspect page permissions.
- [ ] Deliberately violate a permission in a separate boot.

**Invariant:** writable data need not be executable.

**Observable result:** valid access works and invalid access reaches page-fault logging.

### E6 — Unmap, invalidate, and guard stacks

- [ ] Unmap one page and invalidate its TLB entry.
- [ ] Put an unmapped guard page beside important stacks.

**Invariant:** removed translations stop working immediately.

**Observable result:** guard-page access reaches the expected fault path.

### E7 — Kernel heap and Odin allocator

- [ ] Build a small allocator over owned virtual pages.
- [ ] Expose it through Odin's allocator interface.
- [ ] Keep logging and panic independent from it.

**Invariant:** allocation failure is explicit and cannot disable diagnostics.

**Observable result:** allocation tests pass and forced exhaustion fails cleanly.

---

## Phase F: Interrupts and kernel tasks

### F0 — Choose and pin the interrupt-controller path

- [ ] Pin the QEMU machine model.
- [ ] Choose a clearly labeled QEMU-only PIC/PIT path or add ACPI/APIC work.
- [ ] Route and acknowledge one external interrupt without adding a timer yet.

**Invariant:** every delivered hardware interrupt is routed and acknowledged once.

**Observable result:** one controlled external interrupt increments one counter.

### F1 — Program one timer

- [ ] Configure a timer at a known rate.
- [ ] Count ticks with minimal ISR work.
- [ ] Measure rather than assume the rate.

**Invariant:** timer handling cannot block on logging or allocation.

**Observable result:** tick counts track elapsed QEMU time within a stated tolerance.

### F2 — Critical sections and IRQ-safe state

- [ ] Demonstrate an interrupt/task race on one CPU.
- [ ] Protect one shared structure with a minimal critical section.
- [ ] Learn compiler and device-memory ordering before MMIO/DMA work.

**Invariant:** shared scheduler state cannot be observed half-updated.

**Observable result:** a stress test no longer breaks the protected invariant.

### F3 — One stack trampoline and voluntary switch

- [ ] Create one task stack with correct ABI alignment.
- [ ] Enter it through a trampoline.
- [ ] Save and restore required general-purpose state.

**Invariant:** a task starts and returns or exits through a defined path.

**Observable result:** control enters one new stack and returns safely.

### F4 — Two yielding tasks and a run queue

- [ ] Switch at explicit yield points.
- [ ] Add task states and the smallest run queue.

**Invariant:** only runnable tasks are selected and each owns its stack.

**Observable result:** two tasks alternate for thousands of voluntary switches.

### F5 — Timer-driven preemption

- [ ] Reuse the interrupted frame instead of inventing a second format.
- [ ] Add a simple round-robin choice.
- [ ] Keep FP/SIMD forbidden until its state has a policy and tests.

**Invariant:** a non-yielding task cannot block another runnable task forever.

**Observable result:** two non-yielding integer-only tasks both make progress.

---

## Phase G: User/kernel boundary

### G0 — Enter ring 3

- [ ] Add required user descriptors and a TSS kernel stack.
- [ ] Create one user stack.
- [ ] Enter with a controlled `IRETQ` frame.

**Invariant:** user code runs with user privilege and a known address space.

**Observable result:** GDB and a controlled trap confirm ring 3 execution.

### G1 — Contain a user fault

- [ ] Trigger a privileged or invalid user instruction.
- [ ] Terminate only the offending task.

**Invariant:** a user fault does not panic the whole kernel.

**Observable result:** one bad task dies while another continues.

### G2 — A register-only system call

- [ ] Start with an `INT` gate before adding `SYSCALL/SYSRET` complexity.
- [ ] Pass one byte in a register to a `putc` system call.
- [ ] Validate call number and return value.

**Invariant:** user code reaches only declared kernel entry points.

**Observable result:** a user byte prints through the kernel.

### G3 — Validate user buffers

- [ ] Add bounded copy-in or copy-out.
- [ ] Test unmapped, kernel, overflowed, and cross-page ranges.

**Invariant:** the kernel never trusts a user pointer directly.

**Observable result:** valid buffers work and invalid buffers return errors.

### G4 — Parse a small ELF executable

- [ ] Parse headers with checked arithmetic.
- [ ] Reject malformed, overlapping, or unsupported segments.
- [ ] Host-test the parser before loading anything in kernel space.

**Invariant:** only validated load ranges can affect a process address space.

**Observable result:** a corpus of valid and invalid tiny ELFs has expected results.

### G5 — Load two isolated processes

- [ ] Map validated ELF segments and user stacks.
- [ ] Start, schedule, and exit two processes.

**Invariant:** one process cannot access another process's writable pages.

**Observable result:** both run, while a deliberate cross-process access faults.

### G6 — Boot files and a tiny VFS

- [ ] Start with a Limine module or in-memory archive.
- [ ] Define only open, read, and close operations first.

**Invariant:** file contents have one owner and bounded reads.

**Observable result:** a user program reads one file through system calls.

---

## Phase H: Optional network and distributed task branch

User mode is not required for a kernel network driver. This branch requires
owned memory, interrupts or polling, and synchronization. It can begin after
Phase F if distributed work matters more than user processes and files.

### H0 — Host-test packet and ring data structures

- [ ] Parse truncated, oversized, and malformed inputs under Linux tests.
- [ ] Model descriptor ownership transitions without a device.

**Invariant:** untrusted lengths cannot cause out-of-bounds access.

**Observable result:** malformed-input tests fail safely.

### H1 — PCI enumeration

- [ ] Pin the QEMU PCI topology.
- [ ] Enumerate devices and capabilities without writing them.

**Invariant:** configuration traversal is bounded and cycle-safe.

**Observable result:** the expected VirtIO device and capabilities are identified.

### H2 — Modern VirtIO PCI negotiation

- [ ] Pin modern or transitional mode explicitly.
- [ ] Follow reset, acknowledge, driver, feature, and ready status order.
- [ ] Reject unsupported features.

**Invariant:** the driver uses only mutually accepted features.

**Observable result:** device status reaches ready or a clear failure state.

### H3 — One split virtqueue

- [ ] Allocate DMA-visible physical buffers.
- [ ] Add descriptor, available, and used rings.
- [ ] State ownership and memory-ordering rules for each transition.

**Invariant:** one ring entry has exactly one owner at a time.

**Observable result:** a host-tested model and device inspection agree.

### H4 — Polling transmit

**Invariant:** the driver does not reuse a transmit buffer before completion.

**Observable result:** QEMU or the host captures one expected Ethernet frame.

### H5 — Polling receive

**Invariant:** received lengths are checked before packet parsing.

**Observable result:** one valid frame is accepted and one malformed frame is dropped.

### H6 — Interrupt completion

Replace polling only after polling works.

**Invariant:** interrupt completion preserves the same ownership transitions.

**Observable result:** traffic continues with polling disabled.

### H7 — Ethernet and ARP

- [ ] Pin MAC and IPv4 addresses.
- [ ] Define a reproducible host↔guest topology.

**Invariant:** only valid local frames and bounded ARP records update state.

**Observable result:** the guest and host resolve each other's addresses.

### H8 — IPv4

**Invariant:** version, header length, total length, and checksum are validated.

**Observable result:** one valid packet passes and corrupted packets are dropped.

### H9 — UDP

**Invariant:** UDP lengths remain inside the validated IPv4 payload.

**Observable result:** the kernel exchanges one datagram with a host process.

### H10 — Host-to-guest named task

Use the smallest protocol:

```text
worker -> coordinator: READY
coordinator -> worker: RUN 1 ADD 20 22
worker -> coordinator: DONE 1 42
```

Add framing, task IDs, and duplicate suppression before retry logic.

**Invariant:** a duplicate task message cannot produce two accepted results.

**Observable result:** one host-submitted `ADD` task returns `42`.

### H11 — Second QEMU guest

- [ ] Build an explicit shared guest network; default QEMU user networking is
  not automatically a two-guest LAN.
- [ ] Add timeout and retry behavior after duplicate handling exists.

**Invariant:** node loss cannot make a completed task appear both lost and complete.

**Observable result:** bringing a second guest online lets it accept queued work.

## Deferred topics

- Real hardware
- Multiple CPU cores
- USB, sound, and a graphical desktop
- TCP
- Direct UEFI loading
- Distributed consensus
- Process migration
- Distributed filesystems
- Running untrusted remote code
- Automatic splitting of arbitrary programs

## Learning notes

Add dated notes here when an experiment changes our understanding.

- 2026-08-06: Initial research review split large subsystem lessons into one-
  invariant milestones.

## References

Use specifications for facts and tutorials for orientation. Do not copy code
without checking it against our pinned versions.

- Local Odin compiler truth: `odin version`, `odin build -help`, and
  `odin build . -target:"?"`
- Odin source: <https://github.com/odin-lang/Odin>
- Odin runtime package: <https://pkg.odin-lang.org/base/runtime/>
- Odin FAQ: <https://odin-lang.org/docs/faq/>
- Limine source: <https://github.com/Limine-Bootloader/Limine>
- Limine protocol: <https://github.com/Limine-Bootloader/limine-protocol>
- Limine x86-64 C template, used only as a protocol/build reference:
  <https://github.com/Limine-Bootloader/limine-c-template-x86-64>
- OSDev Getting Started: <https://wiki.osdev.org/Getting_Started>
- OSDev Required Knowledge: <https://wiki.osdev.org/Required_Knowledge>
- OSDev suggested order:
  <https://wiki.osdev.org/What_Order_Should_I_Make_Things_In%3F>
- OSDev serial ports: <https://wiki.osdev.org/Serial_Ports>
- OSDev interrupt service routines:
  <https://wiki.osdev.org/Interrupt_Service_Routines>
- Intel architecture manuals:
  <https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>
- Operating Systems: Three Easy Pieces: <https://pages.cs.wisc.edu/~remzi/OSTEP/>
- VirtIO 1.2 specification:
  <https://docs.oasis-open.org/virtio/virtio/v1.2/virtio-v1.2.html>
- QEMU GDB use: <https://qemu.readthedocs.io/en/latest/system/gdb.html>
- QEMU networking: <https://qemu.readthedocs.io/en/master/system/devices/net.html>
