# composio-nix

[![CI](https://github.com/mehy3dd1nov/composio-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/mehy3dd1nov/composio-nix/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Nix packaging and declarative agent skill distribution for the **Composio Universal CLI** (`@composio/cli`).

> [!WARNING]
> **Community Disclaimer**: This packaging, flake derivation, and skill integration were vibecoded using AI pair-programming agents with human validation. While tested on NixOS and verified against 26.11 standards, please inspect the derivations and report issues if you encounter unexpected edge cases.

---

## Why this exists

Official distribution of `@composio/cli` bundles single-file binaries compiled with [Bun](https://bun.sh). On NixOS:
- Running standard installation scripts fails immediately due to the missing standard Linux dynamic linker (`/lib64/ld-linux-x86-64.so.2`).
- Standard packaging using `autoPatchelfHook` or `patchelf --set-rpath` modifies the ELF dynamic section table, shifting byte offsets and corrupting Bun's embedded trailing ZIP archive. This causes an immediate **`SIGSEGV` (exit code 139)** on startup.

**composio-nix** solves this via:
1. **Surgical In-Place Linker Patching**: Patches `PT_INTERP` directly to NixOS glibc's dynamic loader without mutating section offsets or setting `DT_RUNPATH`.
2. **Companion Colocation**: Preserves runtime ESM services (`services/*.mjs`) and bridges them relative to `process.execPath` via high-performance binary wrappers.
3. **Sub-binary Relinking**: Correctly patches and links bundled secondary binaries (such as the 230MB OpenAI Codex Agent Client Protocol adapter, `codex-acp`).
4. **Agent Skill Export**: Declaratively exports the official `composio-cli` skill for coding assistants (Google Antigravity, OpenCode, Kilocode, Claude Code).

---

## Supported Architectures

| Architecture | Platform | Verification Status |
| :--- | :--- | :--- |
| `x86_64-linux` | Linux (Intel/AMD) | Verified (Local Workstation) |
| `aarch64-linux` | Linux (ARM64) | Hermetic Pre-compiled |
| `aarch64-darwin` | macOS (Apple Silicon) | CI Tested (`macos-latest` M1/M2) |
| `x86_64-darwin` | macOS (Intel) | Community Best Effort / Untested |

---

## Quick Start

### 1. Ad-Hoc Execution (Run Directly)
```bash
nix run github:mehy3dd1nov/composio-nix -- search "github"
```

Or start the interactive ACP server:
```bash
nix run github:mehy3dd1nov/composio-nix -- acp
```

### 2. Flake Integration

Add `composio-nix` to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    composio-nix = {
      url = "github:mehy3dd1nov/composio-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, composio-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # Method A: Via raw package
      packages.${system}.default = pkgs.buildEnv {
        name = "my-env";
        paths = [ composio-nix.packages.${system}.default ];
      };
    };
}
```

### 3. Home Manager Module (Recommended)

If you use Home Manager, import the module to enable the CLI and automatically link the companion skill to your agent environments (Antigravity & OpenCode):

```nix
{ inputs, ... }: {
  imports = [
    inputs.composio-nix.homeManagerModules.default
  ];

  programs.composio-cli = {
    enable = true;
    enableSkill = true; # Automatically links skill to ~/.gemini/ and ~/.config/opencode/
  };
}
```

---

## Upstream Documentation
- Composio: https://github.com/ComposioHQ/composio
- Documentation: https://docs.composio.dev

---

## License
MIT © [mehy3dd1nov](https://github.com/mehy3dd1nov)
