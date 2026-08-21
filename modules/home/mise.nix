# 为指定用户生成 mise 全局配置但不安装工具
{ username, ... }:
let
  tools = import ../../packages/mise-tools.nix;
in
{
  home = {
    inherit username;
    homeDirectory = "/Users/${username}";
    stateVersion = "26.05";
  };

  programs.mise = {
    enable = true;
    package = null;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableNushellIntegration = false;
    enableZshIntegration = false;

    globalConfig = {
      inherit tools;
    };
  };
}
