# 使用 lib、stdenvNoCC 与 fetchurl 构建固定版本的 Oh My Rime CLI
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "oh-my-rime-cli";
  version = "3.0.0";

  src = fetchurl {
    url = "https://github.com/Mintimate/oh-my-rime-cli/releases/download/v3.0.0/oh-my-rime-cli-v3.0.0-darwin-arm64";
    hash = "sha256-f+4kF/0APg+F10ylGrG/qtGvmW/GBN9m4SiEhrji8is=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/oh-my-rime-cli"
    runHook postInstall
  '';

  meta = {
    description = "Oh My Rime 官方交互式维护工具";
    homepage = "https://github.com/Mintimate/oh-my-rime-cli";
    license = lib.licenses.mit;
    mainProgram = "oh-my-rime-cli";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
