# 组合个人 macOS 配置并注入当前用户与 Flake inputs
{
  inputs,
  username,
  ...
}:
{
  imports = [
    ../../modules/darwin
    ../../modules/homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 7;
  system.primaryUser = username;
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  users.users.${username}.home = "/Users/${username}";

  determinateNix.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit username; };
    users.${username} = import ../../modules/home;
  };
}
