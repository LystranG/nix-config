{
  description = "个人 macOS 系统配置";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  # 使用锁定 inputs 组合 formatter、package 与 personal-mac 输出
  outputs =
    inputs@{
      nixpkgs,
      nix-darwin,
      home-manager,
      determinate,
      ...
    }:
    let
      configurationName = "personal-mac";
      username = "lystran";
    in
    {
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;

      packages.aarch64-darwin.oh-my-rime-cli =
        nixpkgs.legacyPackages.aarch64-darwin.callPackage ./packages/oh-my-rime-cli
          { };

      darwinConfigurations.${configurationName} = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs username; };

        modules = [
          determinate.darwinModules.default
          home-manager.darwinModules.home-manager
          ./hosts/${configurationName}
        ];
      };
    };
}
