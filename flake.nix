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
        agents = {
          antigravity = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Link composio-cli skill to Google Antigravity (~/.gemini/antigravity-cli/skills/).";
          };
          opencode = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Link composio-cli skill to OpenCode (~/.config/opencode/skills/).";
          };
          kilocode = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Link composio-cli skill to Kilocode (~/.config/kilocode/skills/).";
          };
          claude = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Link composio-cli skill to Claude Code (~/.claude/skills/).";
          };
          codex = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Link composio-cli skill and OpenAI agent configuration to Codex (~/.codex/skills/).";
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
            ".gemini/antigravity-cli/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.opencode {
            ".config/opencode/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.kilocode {
            ".config/kilocode/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.claude {
            ".claude/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
          })
          (lib.mkIf cfg.agents.codex {
            ".codex/skills/composio-cli/SKILL.md".source = self.skills.composio-cli;
            ".codex/agents/composio.yaml".source = ./skills/composio-cli/agents/openai.yaml;
          })
          (lib.mkIf cfg.agents.cursor {
            ".cursor/rules/composio.mdc".source = self.skills.composio-cli;
          })
        ];
      };
    };

    skills = {
      composio-cli = ./skills/composio-cli/SKILL.md;
      openai = ./skills/composio-cli/agents/openai.yaml;
    };
  };
}
