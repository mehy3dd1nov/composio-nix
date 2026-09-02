{
  description = "Nix packaging and agent skill distribution for Composio Universal CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAllSystems (
        pkgs: rec {
          composio-cli = pkgs.callPackage ./package.nix { };
          default = composio-cli;
        }
      );

      apps = forAllSystems (
        pkgs: rec {
          composio = {
            type = "app";
            program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.composio-cli}/bin/composio";
          };
          default = composio;
        }
      );

      overlays.default = final: prev: {
        composio-cli = final.callPackage ./package.nix { };
      };

      skills = {
        composio-cli = ./skills/composio-cli/SKILL.md;
      };
    };
}
