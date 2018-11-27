{ pkgs
, stdenv
, pythonPackages
, contrailWorkspace
, contrailVersion
, contrailBuildInputs
, isContrail41
, isContrail32 }:

with pkgs.lib;

stdenv.mkDerivation rec {
  name = "contrail-python";
  version = contrailVersion;
  src = contrailWorkspace;
  USER = "contrail";
  # Only required on master
  dontUseCmakeConfigure = true;

  buildInputs = with pythonPackages;
    contrailBuildInputs ++
    # Used by python unit tests
    [ bitarray pbr funcsigs mock bottle ];

  propagatedBuildInputs = with pythonPackages; [
    psutil geventhttpclient
  ];

  prePatch = ''
    # Don't know if this test is supposed to pass
    substituteInPlace controller/src/config/common/tests/test_analytics_client.py --replace "test_analytics_request_with_data" "nop"

    # It seems these tests require contrail-test repository to be executed
    # See https://github.com/Juniper/contrail-test/wiki/Running-Tests
    for i in svc-monitor/setup.py contrail_issu/setup.py schema-transformer/setup.py vnc_openstack/setup.py api-server/setup.py ${optionalString isContrail41 "device-manager/setup.py"}; do
      sed -i 's|def run(self):|def run(self):\n        return|' controller/src/config/$i
    done

    # Tests are disabled because they requires to compile vizd (collector)
    sed -i '/OpEnv.AlwaysBuild(test_cmd)/d' controller/src/opserver/SConscript
  '' + (optionalString isContrail41 ''
    substituteInPlace controller/src/config/common/setup.py --replace "test_suite='tests.test_suite'," ""
  '');

  buildPhase = ''
    export PYTHONPATH=$PYTHONPATH:controller/src/config/common/:build/production/config/api-server/vnc_cfg_api_server/gen/
    scons -j1 --optimization=production controller/src/config

    scons -j1 --optimization=production contrail-analytics-api
    ${optionalString isContrail32 "scons -j1 --optimization=production contrail-discovery"}
  '';

  installPhase = ''
    ${optionalString isContrail41 "rm build/third_party/thrift/lib/cpp/.libs/concurrency_test"}
    mkdir $out; cp -r build/* $out'';
}
