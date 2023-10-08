{ lib
, stdenv
, buildPythonPackage
, isPyPy
, fetchPypi
, fetchpatch
, pytestCheckHook
, libffi
, pkg-config
, pycparser
, pythonAtLeast
}:

if isPyPy then null else buildPythonPackage rec {
  pname = "cffi";
  version = "1.16.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-vLPvQ+WGZbvaL7GYaY/K5ndkg+DEpjGqVkeAbCXgLMA=";
  };

  patches =  lib.optionals (stdenv.cc.isClang && lib.versionAtLeast (lib.getVersion stdenv.cc) "13") [
    # -Wnull-pointer-subtraction is enabled with -Wextra. Suppress it to allow the following tests
    # to run and pass when cffi is built with newer versions of clang:
    # - testing/cffi1/test_verify1.py::test_enum_usage
    # - testing/cffi1/test_verify1.py::test_named_pointer_as_argument
    ./clang-pointer-substraction-warning.diff
  ] ++  lib.optionals (pythonAtLeast "3.11") [
    # Fix test that failed because python seems to have changed the exception format in the
    # final release. This patch should be included in the next version and can be removed when
    # it is released.
    (fetchpatch {
      url = "https://foss.heptapod.net/pypy/cffi/-/commit/8a3c2c816d789639b49d3ae867213393ed7abdff.diff";
      hash = "sha256-3wpZeBqN4D8IP+47QDGK7qh/9Z0Ag4lAe+H0R5xCb1E=";
    })
  ];

  postPatch = lib.optionalString stdenv.isDarwin ''
    # Remove setup.py impurities
    substituteInPlace setup.py \
      --replace "'-iwithsysroot/usr/include/ffi'" "" \
      --replace "'/usr/include/ffi'," "" \
      --replace '/usr/include/libffi' '${lib.getDev libffi}/include'
  '';

  buildInputs = [ libffi ];

  nativeBuildInputs = [ pkg-config ];

  propagatedBuildInputs = [ pycparser ];

  # The tests use -Werror but with python3.6 clang detects some unreachable code.
  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isClang
    "-Wno-unused-command-line-argument -Wno-unreachable-code -Wno-c++11-narrowing";

  doCheck = !stdenv.hostPlatform.isMusl;

  nativeCheckInputs = [ pytestCheckHook ];

  disabledTests = lib.optionals stdenv.isDarwin [
    # AssertionError: cannot seem to get an int[10] not completely cleared
    # https://foss.heptapod.net/pypy/cffi/-/issues/556
    "test_ffi_new_allocator_1"
  ];

  meta = with lib; {
    maintainers = with maintainers; [ domenkozar lnl7 ];
    homepage = "https://cffi.readthedocs.org/";
    license = licenses.mit;
    description = "Foreign Function Interface for Python calling C code";
  };
}
