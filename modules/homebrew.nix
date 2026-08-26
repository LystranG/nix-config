# 使用 username 将 Homebrew 清单接入 nix-darwin activation
{ username, ... }:
let
  packages = import ../packages/homebrew;
in
{
  homebrew = {
    enable = true;
    user = username;
    inherit (packages) taps brews casks;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };
  };
}
