{ pkgs
, stdenv
, contrailVersion
, contrailBuildInputs
, contrailWorkspace
, isContrail41
}:

stdenv.mkDerivation rec {
  name = "contrail-vrouter-agent-${version}";
  version = contrailVersion;
  src = contrailWorkspace;
  USER = "contrail";
  # Only required on R4.1
  dontUseCmakeConfigure = true;
  NIX_CFLAGS_COMPILE = "-Wno-unused-but-set-variable";
  buildInputs = contrailBuildInputs ++ [ pkgs.makeWrapper ];
  buildPhase = ''
    scons -j2 --optimization=production contrail-vrouter-agent
  '';
  installPhase = ''
    mkdir -p $out/{bin,etc/contrail}
    cp build/production/vnsw/agent/contrail/contrail-vrouter-agent $out/bin/
    cp ${contrailWorkspace}/controller/src/vnsw/agent/contrail-vrouter-agent.conf $out/etc/contrail/
    cp -r build/lib $out/
  '';
  postFixup = ''
    wrapProgram "$out/bin/contrail-vrouter-agent" --prefix PATH ":" "${pkgs.procps}/bin"
  '';
}

