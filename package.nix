{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  makeBinaryWrapper,
  zlib,
  openssl,
  nodejs,
  coreutils,
  testers,
}: let
  sources = {
    x86_64-linux = {
      asset = "composio-linux-x64.zip";
      hash = "sha256-hspW5IO5MVWaAukOyKYqsTLCDZTlgiwdqxs7+F6r/QE=";
    };
    aarch64-linux = {
      asset = "composio-linux-aarch64.zip";
      hash = "sha256-FomeIHhS8wjiOOmFqClQ98g95n+rcv9+GA3IbLMsMuU=";
    };
    aarch64-darwin = {
      asset = "composio-darwin-aarch64.zip";
      hash = "sha256-y1AwEv2gEa+AGiVbAhEXNq6sxu1iku+AtSbDvaufux0=";
    };
  };

  currentSource =
    sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  dirPrefix =
    if stdenv.hostPlatform.isDarwin
    then "composio-darwin-"
    else "composio-linux-";
  archSuffix =
    if stdenv.hostPlatform.isAarch64
    then "aarch64"
    else "x64";
  extractedDir = "${dirPrefix}${archSuffix}";
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "composio-cli";
    version = "0.4.1";
    __structuredAttrs = true;
    strictDeps = true;

    src = fetchurl {
      url = "https://github.com/ComposioHQ/composio/releases/download/@composio/cli@${finalAttrs.version}/${currentSource.asset}";
      inherit (currentSource) hash;
    };

    nativeBuildInputs =
      [
        unzip
        makeBinaryWrapper
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        patchelf
      ];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      (lib.getLib openssl)
      zlib
      stdenv.cc.cc.lib
    ];

    dontStrip = true;
    dontPatchELF = true;

    unpackPhase = ''
      runHook preUnpack
      unzip -q $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/libexec/composio $out/bin
      cp -r ${extractedDir}/* $out/libexec/composio/

      ${lib.optionalString stdenv.hostPlatform.isLinux ''
        # Manual patchelf is intentional: autoPatchelfHook is incompatible with Bun single-file
        # executables (SFE). Bun appends a custom data trailer after the ELF segment table;
        # autoPatchelfHook rewrites the ELF layout in ways that corrupt this trailer and produce
        # a non-functional binary. Manual patchelf with --set-interpreter and --set-rpath is the
        # correct Strategy B approach for SFE binaries (nix-porter §5.1 architectural constraint).
        chmod +w $out/libexec/composio/composio
        patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" $out/libexec/composio/composio
        patchelf --set-rpath "${lib.makeLibraryPath [(lib.getLib openssl) zlib stdenv.cc.cc.lib]}" $out/libexec/composio/composio
        chmod 755 $out/libexec/composio/composio
      ''}

      # Secondary binary: codex-acp
      CODEX_BIN="$out/libexec/composio/acp-adapters/codex/${
        if stdenv.hostPlatform.isDarwin
        then "darwin-"
        else "linux-"
      }${
        if stdenv.hostPlatform.isAarch64
        then "arm64"
        else "x64"
      }/codex-acp"

      ${lib.optionalString stdenv.hostPlatform.isLinux ''
        if [ -f "$CODEX_BIN" ]; then
          chmod +w "$CODEX_BIN"
          patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" "$CODEX_BIN"
          patchelf --set-rpath "${lib.makeLibraryPath [zlib (lib.getLib openssl) stdenv.cc.cc.lib]}" "$CODEX_BIN"
          chmod 755 "$CODEX_BIN"
        fi
      ''}

      ${lib.optionalString stdenv.hostPlatform.isDarwin ''
        if [ -f "$CODEX_BIN" ]; then
          chmod 755 "$CODEX_BIN"
        fi
      ''}

      # Wrap main binary
      makeBinaryWrapper $out/libexec/composio/composio $out/bin/composio \
        --prefix PATH : ${lib.makeBinPath [nodejs coreutils]}

      # Wrap secondary binaries
      if [ -f "$CODEX_BIN" ]; then
        makeBinaryWrapper "$CODEX_BIN" $out/bin/codex-acp \
          --prefix PATH : ${lib.makeBinPath [coreutils]}
      fi

      if [ -f "$out/libexec/composio/acp-adapters/claude-code-acp.mjs" ]; then
        makeBinaryWrapper ${nodejs}/bin/node $out/bin/claude-code-acp \
          --add-flags "$out/libexec/composio/acp-adapters/claude-code-acp.mjs" \
          --prefix PATH : ${lib.makeBinPath [nodejs coreutils]}
      fi

      runHook postInstall
    '';

    postFixup = ''
      patchShebangs $out/libexec/composio
    '';

    passthru = {
      inherit sources;
      tests.version = testers.testVersion {
        package = finalAttrs.finalPackage;
        command = "HOME=$TMPDIR composio --version";
        inherit (finalAttrs) version;
      };
      updateScript = [ ./scripts/update.sh ];
    };

    meta = {
      description = "Composio CLI: Connect AI agents to 1000+ external tools";
      homepage = "https://github.com/ComposioHQ/composio";
      changelog = "https://github.com/ComposioHQ/composio/releases/tag/@composio/cli@${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "composio";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      maintainers = [
        {
          name = "mehy3dd1nov";
          github = "mehy3dd1nov";
        }
      ];
    };
  })
