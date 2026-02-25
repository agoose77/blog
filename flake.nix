{
  description = "2i2c SOW Repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mystmd = {
      url = "git+https://gist.github.com/73cf022e5d9f8ce99d8e9d5bff10e5d9";
      inputs.nixpkgs.follows = "nixpkgs"; # keep nixvim nixpkgs consistent with nixpkgs
    };
  };
  outputs = {
    self,
    nixpkgs,
    mystmd,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        packages = [mystmd.packages.${system}.myst];
      in {
        default = pkgs.mkShell {
          inherit packages;
        };
      }
    );
  };
}
