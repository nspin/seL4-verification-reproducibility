{ lib
, writeText
, gcc49Stdenv
, gcc9Stdenv
, texlive
, mlton20180207
, libffi_3_3
, openjdk11
, z3_4_8_5
}:

{ l4vConfig
}:

let
  bv = l4vConfig.arch == "ARM";

in
self: with self; {

  inherit l4vConfig;


  ### aggregate ###

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
    l4vAll
    graphRefine.all
  ]);


  ### sources ###

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
    seL4 = callPackage ./patched-sel4-source.nix {};
    l4v = callPackage ./patched-l4v-source.nix {};
  };


  ### tools and proofs ###

  l4vWith = callPackage ./l4v.nix {};

  l4vSpec = l4vWith {
    tests = [
      "ASpec"
    ];
  };

  l4vAll = l4vWith {
    tests = [];
    buildStandaloneCParser = bv;
  };

  cProofs = l4vWith {
    tests = [
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

  # binaryVerificationInputs = cProofs;
  binaryVerificationInputs = minimalBinaryVerificationInputs;

  hol4 = callPackage ./hol4.nix {
    stdenv = gcc9Stdenv;
    polyml = polymlForHol4;
  };

  graphRefineInputs = callPackage ./graph-refine-inputs.nix {
    # TODO
    # polyml = polymlForHol4;
  };

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


  ### deps ###

  texliveEnv = with texlive; combine {
    inherit
      collection-fontsrecommended
      collection-latexextra
      collection-metapost
      collection-bibtexextra
      ulem
    ;
  };

  ghcWithPackagesForL4v = callPackage  ./deps/ghc-with-packages-for-l4v {};

  mlton = mlton20180207;

  polymlForHol4 = callPackage ./deps/polyml-for-hol4.nix {
    libffi = libffi_3_3;
  };

  polymlForIsabelle = callPackage ./deps/polyml-for-isabelle.nix {
    libffi = libffi_3_3;
  };

  z3ForIsabelle = callPackage ./deps/z3-for-isabelle.nix {
    stdenv = gcc49Stdenv;
  };

  isabelle = callPackage ./deps/isabelle.nix {
    java = openjdk11;
    polyml = polymlForIsabelle;
    z3 = z3ForIsabelle;
    # z3 = z3_4_8_5;
  };

  isabelleInitialHeaps = callPackage ./isabelle-initial-heaps.nix {};
}
