{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
        ] f;
      nixpkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
          # For easier testing
          config.allowUnfree = true;
        }
      );
    in

    {

      overlays.default = final: prev: {
        strichliste-backend = prev.callPackage ./pkgs/strichliste-backend/package.nix { };
        strichliste-web-frontend = prev.callPackage ./pkgs/strichliste-web-frontend/package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          backend = pkgs.strichliste-backend;
          frontend = pkgs.strichliste-web-frontend;
          default = pkgs.strichliste-web-frontend;
        }
      );

      nixosModules = {
        strichliste = import ./modules/strichliste.nix;
      };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          nixosTest =
            let
              modules = with self.nixosModules; [
                strichliste
              ];
              certs = import "${nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
              test = import ./tests/strichliste.nix { inherit pkgs modules certs; };
            in
            pkgs.nixosTest test;
        }
      );

      formatter = forAllSystems (system: nixpkgsFor.${system}.nixfmt-rfc-style);
    };
}
