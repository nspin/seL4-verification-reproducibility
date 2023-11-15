{ lib
, writeText
, texlive
}:

{ l4vConfig
}:

let
  bv = l4vConfig.arch == "ARM";

  oldNixpkgsSource = builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    ref = "nixos-unstable";
    rev = "d4b654cb468790e7ef204ade22aed9b0d9632a7b";
  };

  oldPkgs = import oldNixpkgsSource {};

in
self: with self; {

  inherit oldPkgs;

  inherit l4vConfig;

  rawSources = {
    seL4 = lib.cleanSource ../../projects/seL4;
    l4v = lib.cleanSource ../../projects/l4v;
    hol4 = lib.cleanSource ../../projects/HOL4;
    graphRefine = lib.cleanSource ../../projects/graph-refine;
    graphRefineNoSeL4 = lib.cleanSourceWith ({
      src = rawSources.graphRefine;
      filter = path: type: builtins.match ".*/seL4-example/.*" path == null;
    });
    graphRefineJustSeL4 = lib.cleanSourceWith ({
      src = rawSources.graphRefine;
      filter = path: type: builtins.match ".*/seL4-example(/.*)?" path != null;
    });
  };

  sources = {
    inherit (rawSources) hol4 graphRefine graphRefineNoSeL4 graphRefineJustSeL4;
    seL4 = callPackage ./sel4-source.nix {};
    l4v = callPackage ./l4v-source.nix {};
  };

  texliveEnv = with texlive; combine {
    inherit
      collection-fontsrecommended
      collection-latexextra
      collection-metapost
      collection-bibtexextra
      ulem
    ;
  };

  isabelle-sha1 = callPackage ./isabelle-sha1.nix {};

  isabelle = callPackage ./isabelle.nix {};

  isabelleInitialHeaps = callPackage ./isabelle-initial-heaps.nix {};

  hol4 = callPackage ./hol4.nix {};

  l4vWith = callPackage ./l4v.nix {};

  l4vSpec = l4vWith {
    testTargets = [
      "ASpec"
    ];
  };

  l4vAll = l4vWith {
    testTargets = [];
    buildStandaloneCParser = bv;
  };

  cProofs = l4vWith {
    testTargets = [
      "CRefine"
    ] ++ lib.optionals bv [
      "SimplExportAndRefine"
    ];
    buildStandaloneCParser = bv;
  };

  minimalBinaryVerificationInputs = l4vWith {
    buildStandaloneCParser = true;
    simplExport = true;
  };

  binaryVerificationInputs = minimalBinaryVerificationInputs;

  graphRefineInputs = callPackage ./graph-refine-inputs.nix {};

  graphRefineWith = callPackage ./graph-refine.nix {};

  graphRefine = rec {
    justStackBounds = graphRefineWith {};
    coverage = graphRefineWith {
      targetDir = justStackBounds;
      commands = [
        [ "trace-to:coverage.txt" "coverage" ]
      ];
    };
    demo = graphRefineWith {
      targetDir = justStackBounds;
      commands = [
        [ "trace-to:report.txt" "deps:Kernel_C.cancelAllIPC" ]
      ];
    };
    all = graphRefineWith {
      targetDir = justStackBounds;
      commands = [
        [ "trace-to:report.txt" "all" ]
      ];
    };
  };

  cached = writeText "cached" (toString [
    isabelle
    isabelleInitialHeaps
    binaryVerificationInputs
    hol4
    graphRefineInputs
    graphRefine.justStackBounds
    graphRefine.coverage
    graphRefine.demo
    l4vSpec
  ]);

  all = writeText "all" (toString [
    cached
    l4vAllTests
    graphRefine.all
  ]);
}
