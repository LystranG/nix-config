# 使用 pkgs 组合 macOS 系统行为与固定的系统级工具
{ pkgs, ... }:
{
  imports = [
    ./system-defaults.nix
  ];

  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
  };

  environment.systemPackages = [
    (pkgs.callPackage ../../packages/oh-my-rime-cli { })
  ];
}
