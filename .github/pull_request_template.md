## Description
<!-- Provide a brief description of your changes and why they are needed. -->

## Changes Made
- [ ] Updated derivation in `package.nix`
- [ ] Updated `flake.nix` or flake outputs
- [ ] Modified skills or documentation

## Verification & Testing
<!-- Select all platforms you have verified this on: -->
- [ ] `x86_64-linux`
- [ ] `aarch64-linux`
- [ ] `aarch64-darwin`
- [ ] `x86_64-darwin`

### Commands Run:
- [ ] `nix flake check`
- [ ] `nix build .#composio-cli`
- [ ] `./result/bin/composio --version`

## Invariant Checks
- [ ] `dontStrip = true;` is preserved (Bun trailer preservation).
- [ ] `dontPatchELF = true;` is preserved for the main Bun binary (avoids `SIGSEGV` exit code 139).
