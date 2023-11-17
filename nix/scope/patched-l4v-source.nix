{ stdenv
, python3
, rawSources
, l4vConfig
}:

stdenv.mkDerivation {
  name = "l4v-source";

  src = rawSources.l4v;

  phases = [ "unpackPhase" "patchPhase" "installPhase" ];

  nativeBuildInputs = [
    python3
  ];

  postPatch = ''
    patchShebangs .

    cpp_files="
      tools/c-parser/isar_install.ML
      tools/c-parser/standalone-parser/tokenizer.sml
      tools/c-parser/standalone-parser/main.sml
      tools/c-parser/testfiles/jiraver313.thy
      "
    for x in $cpp_files; do
      substituteInPlace $x --replace /usr/bin/cpp ${l4vConfig.targetCC}/bin/${l4vConfig.targetPrefix}cpp
    done
  '';

  installPhase = ''
    cp -r . $out
  '';
}
