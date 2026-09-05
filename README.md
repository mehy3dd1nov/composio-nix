# composio-nix

[![CI](https://github.com/mehy3dd1nov/composio-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/mehy3dd1nov/composio-nix/actions/workflows/ci.yml)
[![Stable Releases](https://img.shields.io/badge/Releases-Stable-2ea44f?logo=github)](https://github.com/mehy3dd1nov/composio-nix/releases?q=-is%3Aprerelease)
[![Beta Releases](https://img.shields.io/badge/Releases-Beta%20Track-f0883e?logo=github)](https://github.com/mehy3dd1nov/composio-nix/releases?q=is%3Aprerelease)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Nix packaging and declarative agent skill distribution for the **Composio Universal CLI** (`@composio/cli`).

> [!NOTE]
> **Architecture & Production Standards**: Packaged under Nixpkgs Strategy B (pre-compiled binary patching) complying with Nixpkgs 26.11 ratchets (`__structuredAttrs`, `strictDeps`, open recursion via `finalAttrs`, `makeBinaryWrapper`). All derivations undergo automated CI testing across Linux and Apple Silicon runners, including live Agent Client Protocol (ACP) stdio handshakes.

---

## Why this exists

Official distribution of `@composio/cli` bundles single-file binaries compiled with [Bun](https://bun.sh). On NixOS:
- Running standard installation scripts fails immediately due to the missing standard Linux dynamic linker (`/lib64/ld-linux-x86-64.so.2`).
- Standard packaging using generic `autoPatchelfHook` mutates the ELF segment layout, shifting internal offsets and corrupting Bun's embedded trailing ZIP archive. This causes an immediate **`SIGSEGV` (exit code 139)** on startup.

**composio-nix** solves this via:
1. **Surgical In-Place Linker & RPATH Patching**: Sets `PT_INTERP` to the canonical `stdenv.cc.bintools.dynamicLinker` and injects `DT_RUNPATH` for runtime dependencies (`openssl`, `zlib`, `stdenv.cc.cc.lib`) without corrupting Bun's trailer.
2. **Companion Colocation**: Preserves runtime ESM services (`services/*.mjs`) and bridges them relative to `process.execPath` via high-performance binary wrappers (`makeBinaryWrapper`).
3. **Sub-binary Relinking**: Correctly patches dynamic linkers and library search paths for bundled secondary binaries (such as OpenAI's standalone Rust `codex-acp` adapter).
4. **Agent Skill Export**: Declaratively exports the official `composio-cli` skill with opt-in bindings for coding assistants (Google Antigravity, OpenCode, Kilocode, Claude Code, Codex, Cursor).

---

## Supported Architectures

| Architecture | Platform | Verification Status |
| :--- | :--- | :--- |
| `x86_64-linux` | Linux (Intel/AMD) | Verified (Local Workstation & CI) |
| `aarch64-linux` | Linux (ARM64) | Hermetic Pre-compiled (Dynamic Linker `.so.1`) |
| `aarch64-darwin` | macOS (Apple Silicon) | CI Tested (`macos-latest` M1/M2) |

---

## Release Channels & Branches

| Channel | Branch | Releases Feed | Recommended Use |
| :--- | :--- | :--- | :--- |
| **Stable (Default)** | [`main`](https://github.com/mehy3dd1nov/composio-nix/tree/main) | [Browse Stable Releases (`-is:prerelease`)](https://github.com/mehy3dd1nov/composio-nix/releases?q=-is%3Aprerelease) | Production MCP servers, stable agent toolkits |
| **Unstable** | [`unstable`](https://github.com/mehy3dd1nov/composio-nix/tree/unstable) | [Browse Beta Releases (`is:prerelease`)](https://github.com/mehy3dd1nov/composio-nix/releases?q=is%3Aprerelease) | Bleeding-edge beta features, experimental ACP |

---

## Quick Start

### 1. Ad-hoc Execution

Run the stable CLI directly with `nix run`:
```bash
nix run github:mehy3dd1nov/composio-nix -- --version
```

Or test bleeding-edge beta features from the `unstable` branch:
```bash
nix run github:mehy3dd1nov/composio-nix/unstable -- --version
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

### 3. Multi-Agent Home Manager Module (Recommended)

If you use Home Manager, import the module to install the CLI, expose all ACP adapters, and declaratively wire the companion skills directly into your agent environments:

```nix
{ inputs, ... }: {
  imports = [
    inputs.composio-nix.homeManagerModules.default
  ];

  programs.composio-cli = {
    enable = true;

    # Declaratively enable/disable specific coding agent environments:
    agents = {
      claude = true;      # Claude Code (~/.claude/skills/composio-cli/)
      codex = true;       # OpenAI Codex (~/.codex/skills/ & ~/.codex/agents/)
      antigravity = true; # Google Antigravity (~/.gemini/antigravity-cli/skills/)
      opencode = true;    # OpenCode (~/.config/opencode/skills/)
      kilocode = true;    # Kilocode (~/.config/kilocode/skills/)
      cursor = true;      # Cursor Rules (~/.cursor/rules/composio.mdc)
    };
  };
}
```

### 4. Agent Client Protocol (ACP) & Native Setup

`composio-nix` bundles and exposes high-performance binary adapters for both Anthropic's Claude Code and OpenAI's Codex:

- **Run Claude Code ACP Adapter directly**:
  ```bash
  nix run github:mehy3dd1nov/composio-nix#claude-code-acp
  ```
- **Run OpenAI Codex ACP Adapter directly**:
  ```bash
  nix run github:mehy3dd1nov/composio-nix#codex-acp -- --help
  ```
- **Auto-Configure Agent Hosts**:
  When Claude Code or Codex is present in your PATH, run:
  ```bash
  composio setup --target auto --yes
  ```

---

## Upstream Documentation
- Composio: https://github.com/ComposioHQ/composio
- Documentation: https://docs.composio.dev

---

## License
MIT © [mehy3dd1nov](https://github.com/mehy3dd1nov)
