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
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
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
        codex-acp = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.composio-cli}/bin/codex-acp";
          meta.description = "OpenAI Codex Agent Client Protocol (ACP) adapter";
        };
        claude-code-acp = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.composio-cli}/bin/claude-code-acp";
          meta.description = "Claude Code Agent Client Protocol (ACP) adapter";
        };
        default = composio;
      }
    );

    checks = forAllSystems (
      pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}.composio-cli.passthru.tests) version;
      }
    );

    formatter = forAllSystems (pkgs: pkgs.alejandra);

    overlays.default = final: _: {
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
        agents = {
          antigravity = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Link composio-cli skill directory to Google Antigravity (~/.gemini/antigravity-cli/skills/).";
          };
          opencode = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Link composio-cli skill directory to OpenCode (~/.config/opencode/skills/).";
          };
          kilocode = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Link composio-cli skill directory to Kilocode (~/.config/kilocode/skills/).";
          };
          claude = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Link composio-cli skill directory to Claude Code (~/.claude/skills/).";
          };
          codex = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Link composio-cli skill directory and OpenAI agent configuration to Codex (~/.codex/skills/).";
          };
          cursor = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Link composio-cli skill rules to Cursor (~/.cursor/rules/).";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [cfg.package];
        home.file = lib.mkMerge [
          (lib.mkIf cfg.agents.antigravity {
            ".gemini/antigravity-cli/skills/composio-cli".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.opencode {
            ".config/opencode/skills/composio-cli".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.kilocode {
            ".config/kilocode/skills/composio-cli".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.claude {
            ".claude/skills/composio-cli".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.codex {
            ".codex/skills/composio-cli".source = self.skills.composio-cli;
            ".codex/agents/composio.yaml".source = ./skills/composio-cli/agents/openai.yaml;
          })
          (lib.mkIf cfg.agents.cursor {
            ".cursor/rules/composio.mdc".source = ./skills/composio-cli/SKILL.md;
          })
        ];
      };
    };

    skills = {
      composio-cli = ./skills/composio-cli;
      openai = ./skills/composio-cli/agents/openai.yaml;
    };
  };
}
