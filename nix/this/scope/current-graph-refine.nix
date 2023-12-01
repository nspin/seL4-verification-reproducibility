{ lib
, runCommand
, python2Packages
, python3Packages
, git

, sources
, l4vConfig
, kernelWithCParser
, preprocessedKernelsAreIdentical
, cFunctionsTxt
, asmFunctionsTxt
, currentGraphRefineSolverLists
}:

{ name ? null
, extraNativeBuildInputs ? []
, solverList ? currentGraphRefineSolverLists.default
, source ? sources.currentGraphRefine
, args ? []
, keepSMTDumps ? false
, commands ? ''
    (time python ${source}/graph-refine.py . ${lib.concatStringsSep " " args}) 2>&1 | tee log.txt
  ''
}:

let
  targetPy = source + "/seL4-example/target-${l4vConfig.arch}.py";

  preTargetDir = runCommand "current-graph-refine-initial-target-dir" {
    inherit preprocessedKernelsAreIdentical;
  } ''
    mkdir $out
    cp ${kernelWithCParser}/{kernel.elf.rodata,kernel.elf.txt,kernel.elf.symtab} $out
    cp ${cFunctionsTxt} $out/CFunctions.txt
    cp ${asmFunctionsTxt} $out/kernel_mc_graph.txt
    cp ${targetPy} $out/target.py
  '';

  targetDir = runCommand "current-graph-refine-prepared-target-dir" {
    nativeBuildInputs = [
      python3Packages.python
    ];
  } ''
    cp -r --no-preserve=ownership,mode ${preTargetDir} $out

    python3 ${source + "/seL4-example/functions-tool.py"} \
      --arch ARM \
      --target-dir $out \
      --functions-list-out functions-list.txt.txt \
      --asm-functions-out ASMFunctions.txt \
      --stack-bounds-out StackBounds.txt
  '';

in
runCommand "current-graph-refine${lib.optionalString (name != null) "-${name}"}" {
  nativeBuildInputs = [
    python2Packages.python
    python2Packages.typing
    python2Packages.enum
    python2Packages.psutilForPython2
    git
  ] ++ extraNativeBuildInputs;

  passthru = {
    inherit
      preprocessedKernelsAreIdentical
      preTargetDir
      targetDir
    ;
  };
} ''
  ln -s ${solverList} .solverlist
  cp -r --no-preserve=owner,mode ${targetDir} target
  cd target

  ${commands}

  rm -f target.pyc

  ${lib.optionalString (!keepSMTDumps) ''
    rm -r smt2
  ''}

  cp -r . $out
''
