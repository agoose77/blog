{
  description = "2i2c SOW Repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
        packages = [pkgs.mystmd];
      in {
        default = pkgs.mkShell {
          inherit packages;
        };
      }
    );
  };
}
