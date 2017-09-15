{ pkgs ? import <nixpkgs> {} }:

with import ./deps.nix {inherit pkgs;};
with import ./controller.nix {inherit pkgs;};
with pkgs;

rec {

  webuiThirdPartySrc = fetchFromGitHub {
    owner = "Juniper";
    repo = "contrail-webui-third-party";
    rev = "e8c29f64a03f611bafd719fd0d3c38aaaf5824a3";
    sha256 = "19xf43nwdrs57k5ssqzbnra3h912px8ywcmb734wvy7v339xvgrb";
  };

  webControllerSrc = fetchFromGitHub {
    owner = "Juniper";
    repo = "contrail-web-controller";
    rev = "97a6f72aa66cfc32a94c4dba49f08dd40d627f6f";
    sha256 = "17s892xb6b0spnkgld2ywb32bvhrrhb1dyqg2fg45izwq7ib6wks";
  };

  webCoreSrc = fetchFromGitHub {
    owner = "Juniper";
    repo = "contrail-web-core";
    rev = "652086f83c02f36f872b1f70e96a4665566abd8e";
    sha256 = "13f69sxvs0gljkhayjbavq2s3anmv3x68884nlx6n9359rlnvwgj";
  };

  webuiThirdPartyCommon = {
    version = "3.2";
    src = webuiThirdPartySrc;
    phases = [ "unpackPhase" "patchPhase" "buildPhase" "installPhase" ];
    buildInputs = [ python pythonPackages.lxml unzip wget nodejs-4_x ];
    # https://www.reddit.com/r/NixOS/comments/6eit9b/request_for_assistance_in_creating_a_derivation/
    HOME=".";
    postPatch = ''
      substituteInPlace fetch_packages.py --replace \
        "_PACKAGE_CACHE='/tmp/cache/' + os.environ['USER'] + '/webui_third_party" \
        "_PACKAGE_CACHE='$(pwd)/cache/"
    '';
  };

  nodeHeaders = pkgs.fetchzip {
    url = https://nodejs.org/download/release/v4.8.4/node-v4.8.4-headers.tar.gz;
    sha256="1w8bj7y9fgpbz3177l57584rlf0ark12igjq1zrn9bjlppkhqv6h";
  };

  webuiThirdPartyCache = stdenv.mkDerivation (webuiThirdPartyCommon // {
    name = "contrail-webui-third-party-cache";
    impureEnvVars = pkgs.stdenv.lib.fetchers.proxyImpureEnvVars;
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "1cgk3idlggdaiky2q8fc4a9lif6nxv8apgfpnl2l87bbas4101am";
    postPatch = webuiThirdPartyCommon.postPatch + ''
      substituteInPlace fetch_packages.py --replace \
        "os.remove(ccfile)" \
        "pass"
    '';
    buildPhase = "python fetch_packages.py -f packages.xml";
    installPhase = ''
      mkdir -p $out/{cache,node_modules}

      # We remove some generated files and keep the npm cache
      rm -rf node_modules/webworker-threads/
      rm -rf cache/node_modules/webworker-threads/
      cp -ra .npm $out/.npm/

      cp -ra cache/* $out/cache/
      cp -ra node_modules/*.tar.gz $out/node_modules/
    '';
  });

  webuiThirdParty = stdenv.mkDerivation (webuiThirdPartyCommon // {
    name = "contrail-webui-third-party";
    buildPhase = ''
      cp -r ${webuiThirdPartyCache}/cache ./
      cp -r ${webuiThirdPartyCache}/node_modules ./
      cp -r ${webuiThirdPartyCache}/.npm ./
      chmod -R u+w cache node_modules .npm
      python fetch_packages.py -f packages.xml
    '';
    postPatch = webuiThirdPartyCommon.postPatch + ''
      substituteInPlace fetch_packages.py --replace \
        "cmd = ['npm', 'install', ccfile, '--prefix', _PACKAGE_CACHE]" \
        "cmd = ['npm', 'install', '--verbose', '--nodedir=${nodeHeaders}', ccfile, '--prefix', _PACKAGE_CACHE]"
    '';
    installPhase = "mkdir $out; cp -ra node_modules $out/";
  });

  webBuild = stdenv.mkDerivation {
    name = "contrail-web-build";
    version = "3.2";

    srcs = [ webuiThirdParty webCoreSrc webControllerSrc controller generateds ];

    phases = [ "unpackPhase" "buildPhase" "installPhase" ];

    buildInputs = [
      python pythonPackages.lxml nodejs-4_x rsync
    ];

    sourceRoot = "./";

    postUnpack = "
      mkdir tools
      mv ${generateds.name} tools/generateds
      [[ ${controller.name} != controller ]] && mv ${controller.name} controller
      mv ${webCoreSrc.name} contrail-web-core
      mv ${webControllerSrc.name} contrail-web-controller
      rsync -a ${webuiThirdParty.name}/node_modules contrail-web-core
      rsync -a ${webuiThirdParty.name}/node_modules contrail-web-controller
    ";

    buildPhase = ''
      cp contrail-web-core/config/config.global.js contrail-web-core/config/config.global.js.orig
      substituteInPlace contrail-web-core/config/config.global.js --replace \
        "/usr/src/contrail/contrail-web-controller" \
        "$(pwd)/contrail-web-controller"

      # start build
      cd contrail-web-core
      cp -a webroot/html/dashboard.tmpl webroot/html/dashboard.html
      cp -a webroot/html/login.tmpl webroot/html/login.html
      cp -a webroot/html/login-error.tmpl webroot/html/login-error.html
      ./generate-files.sh 'dev-env' webController
      ./dev-install.sh
      rm -f built_version
      ./build-files.sh 'prod-env' webController
      ./prod-dev.sh webroot/html/dashboard.html prod_env dev_env true
      ./prod-dev.sh webroot/html/login.html prod_env dev_env true
      ./prod-dev.sh webroot/html/login-error.html prod_env dev_env true
      # end build

      # patch webserver so it doesn't try to write file in the package dir
      cp webroot/img/opencontrail-favicon.ico webroot/img/sdn-favicon.ico
      cp webroot/img/opencontrail-logo.png webroot/img/sdn-logo.png
      substituteInPlace webServerStart.js --replace \
        "doPreStartServer(false);" \
        "" \
      # files generated by the webserver
      ln -s /tmp/contrail-web-core-regions.js webroot/common/api/regions.js
      ln -s /tmp/contrail-web-core-menu_wc.xml webroot/menu_wc.xml

      # allow user to provide configuration in /tmp/contrail-web-core-config.js
      rm -f config/config.global.js
      ln -s /tmp/contrail-web-core-config.js config/config.global.js

      cd ..
    '';

    installPhase = ''
      mkdir -p $out
      cp -r * $out
    '';
    };

    webController = stdenv.mkDerivation {
      name = "contrail-web-controller";
      version = "3.2";

      src = webBuild;
      phases = [ "unpackPhase" "installPhase" ];

      installPhase = ''
        mkdir $out; cp -r contrail-web-controller/* $out
      '';
    };
    
    webCore = stdenv.mkDerivation {
      name = "contrail-web-core";
      version = "3.2";

      src = webBuild;
      phases = [ "unpackPhase" "installPhase" ];

      installPhase = ''
        mkdir $out; cp -r contrail-web-core/* $out
      '';
    };

  }
