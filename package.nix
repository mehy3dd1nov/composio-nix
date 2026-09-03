{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  makeBinaryWrapper,
  glibc,
  zlib,
  openssl,
  nodejs,
  coreutils,
  testers,
}: let
  pname = "composio-cli";
  version = "0.4.1-beta.374";

  sources = {
    x86_64-linux = {
      asset = "composio-linux-x64.zip";
      hash = "sha256-8zLCehIsiraUeKnM1j3s44yHeF1qDgHr0D/X8kAg/tg=";
    };
    aarch64-linux = {
      asset = "composio-linux-aarch64.zip";
      hash = "sha256-EX6fs/FBQ3xzCXBbO2BvscA3meq7RQO7dfWgI/I6bLE=";
    };
    x86_64-darwin = {
      asset = "composio-darwin-x64.zip";
      hash = "sha256-vyt082EYtPF9uMkWBbhCN2bvvF1mUFRWfMrwByyKvMQ=";
    };
    aarch64-darwin = {
      asset = "composio-darwin-aarch64.zip";
      hash = "sha256-r9zS9SKJXjJONPLw8TBjs39iTCaEDjTj64pmtbLMmHg=";
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
    inherit pname version;
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
      glibc
      openssl
      zlib
      stdenv.cc.cc.lib
    ];

    # Invariant: Stripping truncates Bun appended bytecode and causes SIGSEGV
    dontStrip = true;
    # Invariant: autoPatchelfHook injects DT_RUNPATH into Bun binary causing SIGSEGV
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
        # 1. Surgical in-place interpreter patch for Bun single-file executable
        GLIBC_LD="${glibc}/lib/ld-linux-${
          if stdenv.hostPlatform.isAarch64
          then "aarch64"
          else "x86-64"
        }.so.2"
        chmod +w $out/libexec/composio/composio
        patchelf --set-interpreter "$GLIBC_LD" $out/libexec/composio/composio
        chmod 755 $out/libexec/composio/composio
      ''}

      # 2. Patch secondary codex-acp binary
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
          patchelf --set-interpreter "$GLIBC_LD" "$CODEX_BIN"
          patchelf --set-rpath "${lib.makeLibraryPath [glibc zlib openssl.out stdenv.cc.cc.lib]}" "$CODEX_BIN"
          chmod 755 "$CODEX_BIN"
        fi
      ''}

      if [ -f "$CODEX_BIN" ]; then
        ln -s "$CODEX_BIN" "$out/bin/codex-acp"
      fi

      # 3. Create high-performance binary wrappers
      makeBinaryWrapper $out/libexec/composio/composio $out/bin/composio \
        --prefix PATH : ${lib.makeBinPath [nodejs coreutils]}

      if [ -f "$out/libexec/composio/acp-adapters/claude-code-acp.mjs" ]; then
        makeBinaryWrapper ${nodejs}/bin/node $out/bin/claude-code-acp \
          --add-flags "$out/libexec/composio/acp-adapters/claude-code-acp.mjs" \
          --prefix PATH : ${lib.makeBinPath [nodejs coreutils]}
      fi

      runHook postInstall
    '';

    passthru.tests = {
      version = testers.testVersion {
        package = finalAttrs.finalPackage;
        command = "HOME=$TMPDIR composio --version";
        inherit (finalAttrs) version;
      };
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
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      maintainers = with lib.maintainers; [];
    };
  })
