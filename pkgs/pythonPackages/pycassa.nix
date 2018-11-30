{ buildPythonPackage
, fetchPypi
, thrift
}:

buildPythonPackage rec {
  pname = "pycassa";
  version = "1.11.0";
  name = "${pname}-${version}";
  src = fetchPypi {
    inherit pname version;
    sha256 = "2c75f6f83a6208dabf4be3f29c96effae94027467332ee94c85ce133517ab493";
  };
  # Tests are not executed since they require a cassandra up and
  # running
  doCheck = false;
  propagatedBuildInputs = [ thrift ];
}
