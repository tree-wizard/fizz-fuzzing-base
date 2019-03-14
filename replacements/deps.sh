JOBS=2
USAGE="./deps.sh [-j num_jobs]"
while [ "$1" != "" ]; do
  case $1 in
    -j | --jobs ) shift
                  JOBS=$1
                  ;;
    * )           echo $USAGE
                  exit 1
esac
shift
done

set -e
start_dir=$(pwd)
trap 'cd $start_dir' EXIT

folly_rev=$(sed 's/Subproject commit //' "$start_dir"/../build/deps/github_hashes/facebook/folly-rev.txt)

# Must execute from the directory containing this script
cd "$(dirname "$0")"


if ! apt-get install -y libgoogle-glog-dev;
then
  if [ ! -e google-glog ]; then
    echo "fetching glog from svn (apt-get failed)"
    svn checkout https://google-glog.googlecode.com/svn/trunk/ google-glog
    (
      cd google-glog
      ./configure
      make
      make install
    )
  fi
fi
if ! apt-get install -y libgflags-dev;
then
  if [ ! -e google-gflags ]; then
    echo "Fetching gflags from svn (apt-get failed)"
    svn checkout https://google-gflags.googlecode.com/svn/trunk/ google-gflags
    (
      cd google-gflags
      ./configure
      make
     make install
    )
  fi
fi

if  ! apt-get install -y libdouble-conversion-dev;
then
  if [ ! -e double-conversion ]; then
    echo "Fetching double-conversion from git (apt-get failed)"
    git clone https://github.com/floitsch/double-conversion.git double-conversion
    (
      cd double-conversion
      cmake . -DBUILD_SHARED_LIBS=ON
      make install
    )
  fi
fi


# Get folly
cd folly


# Build folly
mkdir -p _build
cd _build
CXX=clang++-7 CXXFLAGS='-ggdb -fsanitize=fuzzer-no-link,undefined' cmake configure .. -DFOLLY_ASAN_ENABLED=1 -DFOLLY_USE_SYMBOLIZER=1 -DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
#cmake configure .. -DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
make -j$JOBS
make install

cd ../..


# Get fizz
cd fizz

# Build Fizz
mkdir -p _build
cd _build
CXX=clang++-7 CXXFLAGS='-g -fsanitize=fuzzer-no-link,address,undefined' cmake configure ../fizz
make -j$JOBS
make install
cd ../..

#Get Wangle
cd wangle

# Build wangle
mkdir -p _build
cd _build
CXX=clang++-7 CXXFLAGS='-g -fsanitize=fuzzer-no-link,address,undefined' cmake configure ../wangle -DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
make -j$JOBS
make install
cd ../..

# Build proxygen
autoreconf -ivf
./configure CXX=clang++-7 CXXFLAGS='-g -fsanitize=fuzzer-no-link,undefined,address' CC=clang-7 CFLAGS='-g -fsanitize=fuzzer-no-link,address,undefined'
make -j$JOBS

# Run tests
LD_LIBRARY_PATH=/usr/local/lib make

make install
