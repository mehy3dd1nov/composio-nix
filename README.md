# composio-nix

Production-grade Nix packaging and declarative agent skill distribution for the **Composio Universal CLI** (`@composio/cli`).

---

## Features

- **Native Execution**: Surgical ELF dynamic linker patching for Bun single-file executables without `DT_RUNPATH` corruption.
- **Full Ecosystem Support**: Colocates runtime ESM services and patches secondary Agent Client Protocol (`codex-acp`) binaries.
- **Multi-Architecture**: Supports `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, and `aarch64-darwin`.
- **Agent Skill Included**: Distributes the official `composio-cli` skill for Google Antigravity, OpenCode, Kilocode, and Claude Code.

---

## Quick Start

### Run directly via Nix Flake
```bash
nix run github:mhydnv/composio-nix -- search "github"
```

### Add to Flake Inputs
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    composio-nix = {
      url = "github:mhydnv/composio-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, composio-nix, ... }: {
    # In your home-manager or NixOS configuration:
    # home.packages = [ composio-nix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
}
```

---

## Upstream Documentation
- Composio: https://github.com/ComposioHQ/composio
- Documentation: https://docs.composio.dev
