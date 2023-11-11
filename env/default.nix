let
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    ref = "nixos-unstable";
    rev = "85f1ba3e51676fa8cc604a3d863d729026a6b8eb";
  };

  pkgs = import nixpkgs {};

  inherit (pkgs) lib;

  etc = {
    passwd = ''
      root:x:0:
      nixbld:!:100:
      nogroup:x:65534:
    '';

    group = ''
      root:x:0:0:Nix build user:/build:/noshell
      nixbld:x:1000:100:Nix build user:/build:/noshell
      nobody:x:65534:65534:Nobody:/:/noshell
    '';

    hosts = ''
      127.0.0.1 localhost
      ::1 localhost
    '';
  };

  etcFiles = lib.mapAttrs builtins.toFile etc;

  image = pkgs.dockerTools.buildImage {
    name = "minimal";

    copyToRoot = pkgs.runCommand "root" {} ''
      mkdir $out
      cd $out
      mkdir tmp build bin etc
      ln -s /env/bin/bash bin/sh
      cp ${etcFiles.passwd} etc/passwd
      cp ${etcFiles.group} etc/group
      cp ${etcFiles.hosts} etc/hosts
    '';

    config = {
      WorkingDir = "/x";
      Env = [
        "NIX_REMOTE=daemon"
        "NIX_BUILD_SHELL=bash"
        "NIX_SSL_CERT_FILE=/env/etc/ssl/certs/ca-bundle.crt"
        "HOME=/homless-shelter"
        "PATH=/env/bin"
      ];
    };
  };

  env = pkgs.buildEnv {
    name = "env";
    paths = with pkgs; [
      nix
      cacert
      busybox
      bashInteractive
    ];
  };

in {
  inherit image env;
}
