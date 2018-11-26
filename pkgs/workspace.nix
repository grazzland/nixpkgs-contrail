{ pkgs
, stdenv
, isContrail32
, isContrail41
, contrailVersion
, contrailBuildInputs
, contrailSources
, contrailThirdParty
, contrailController }:

with pkgs.lib;

stdenv.mkDerivation rec {
  name = "contrail-workspace";
  version = contrailVersion;
  buildInputs = contrailBuildInputs;
  USER = "contrail";
  # Only required on R4.1
  dontUseCmakeConfigure = true;

  phases = [ "unpackPhase" "patchPhase" "configurePhase" "buildPhase" "installPhase" "fixupPhase" ];

  # We don't override the patchPhase to be nix-shell compliant
  preUnpack = ''mkdir workspace || exit; cd workspace'';

  srcs = with contrailSources;
    [ build contrailThirdParty generateds sandesh vrouter neutronPlugin contrailController ];

  sourceRoot = "./";

  postUnpack = with contrailSources; ''
    cp ${build.out}/SConstruct .

    mkdir tools
    mv ${build.name} tools/build
    mv ${generateds.name} tools/generateds
    mv ${sandesh.name} tools/sandesh

    [[ ${contrailController.name} != controller ]] && mv ${contrailController.name} controller
    [[ ${contrailThirdParty.name} != third_party ]] && mv ${contrailThirdParty.name} third_party
    find third_party -name configure -exec chmod 755 {} \;
    [[ ${vrouter.name} != vrouter ]] && mv ${vrouter.name} vrouter

    mkdir openstack
    mv ${neutronPlugin.name} openstack/neutron_plugin
  '';

  prePatch = ''
    # Should be moved in build drv
    sed -i 's|def UseSystemBoost(env):|def UseSystemBoost(env):\n    return True|' -i tools/build/rules.py

    sed -i 's|--proto_path=/usr/|--proto_path=${pkgs.protobuf2_5}/|' tools/build/rules.py

    # GenerateDS crashes woth python 2.7.14 while it works with python 2.7.13
    # See https://bugs.launchpad.net/opencontrail/+bug/1721039
    sed -i 's/        parser.parse(infile)/        parser.parse(StringIO.StringIO(infile.getvalue()))/' tools/generateds/generateDS.py
  '';

  # build sandesh here to avoid building it multiple times in control, vrouterAgent, etc...
  buildPhase = ''
    scons -j1 --optimization=production tools/sandesh/library/common
    ln -sf ../../third_party/rapidjson/include/rapidjson build/include
    ln -sf ../../third_party/tbb-2018_U5/include/tbb build/include
    ln -sf ../../../third_party/openvswitch-2.3.0/include build/include/openvswitch
    ln -sf ../../../third_party/openvswitch-2.3.0/lib build/include/openvswitch
  '' + optionalString isContrail41 ''
    ln -sf ../../third_party/SimpleAmqpClient/src/SimpleAmqpClient build/include
  '';

  installPhase = "mkdir $out; cp -r ./ $out";
}
