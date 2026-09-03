# Contributing to composio-nix

Contributions are welcome! Whether reporting edge cases, packaging updates, or testing on Darwin architectures, here is how to get started.

---

## Local Development Workflow

1. **Clone and enter the repository**:
   ```bash
   git clone https://github.com/mehy3dd1nov/composio-nix.git
   cd composio-nix
   ```

2. **Test evaluating and building**:
   ```bash
   nix flake check
   nix build .#composio-cli
   ./result/bin/composio --version
   ```

3. **Running the automated updater locally**:
   ```bash
   ./scripts/update.sh
   ```

---

## Critical Packaging Invariants

When editing [`package.nix`](./package.nix):
- **Never enable stripping (`dontStrip = true`)**: Bun executables append bytecode/zip payloads to the end of the ELF/Mach-O file. Stripping removes or invalidates this trailer.
- **Never use `autoPatchelfHook` on the main Bun executable (`dontPatchELF = true`)**: Injecting `DT_RUNPATH` shifts dynamic sections and corrupts Bun's trailer offset, causing an immediate `SIGSEGV` (exit code 139). Only in-place `PT_INTERP` patching is safe.
- **Secondary binaries (`codex-acp`)**: Must be patched separately with standard `patchelf --set-interpreter` and `patchelf --set-rpath`.

---

## Submitting Pull Requests

1. Run `nix flake check` and test the binary execution.
2. Fill out the [Pull Request Template](./.github/pull_request_template.md).
3. The automated CI matrix (`ubuntu-latest` and `macos-latest`) will run validation on your PR automatically.
