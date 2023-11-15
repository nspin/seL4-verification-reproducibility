let
  pkgs = import ../nixpkgs {
    overlays = [
      (import ./overlay)
    ];
  };
in pkgs.this.default // {
  inherit pkgs;
}
