{
  description = "Nix packaging and agent skill distribution for Composio Universal CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {inherit system;}));
  in {
    packages = forAllSystems (
      pkgs: rec {
        composio-cli = pkgs.callPackage ./package.nix {};
        default = composio-cli;
      }
    );

    apps = forAllSystems (
      pkgs: rec {
        composio = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.composio-cli}/bin/composio";
          meta.description = "Composio Universal CLI";
        };
        default = composio;
      }
    );

    overlays.default = final: prev: {
      composio-cli = final.callPackage ./package.nix {};
    };

    homeManagerModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.programs.composio-cli;
    in {
      options.programs.composio-cli = {
        enable = lib.mkEnableOption "Composio Universal CLI";
        package = lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "composio-cli" {};
        enableSkill = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to link the composio-cli skill to Antigravity and OpenCode.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [cfg.package];
        home.file = lib.mkIf cfg.enableSkill {
          ".gemini/antigravity-cli/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
          ".config/opencode/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
        };
      };
    };

    skills = {
      composio-cli = ./skills/composio-cli/SKILL.md;
    };
  };
}
