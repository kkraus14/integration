#!/bin/bash
set +e
set -x

# mwendt: missing critical redirect
export HOME=$WORKSPACE
export LIBCUDF_KERNEL_CACHE_PATH=$WORKSPACE/.cache/rapids/cudf

# FIXME: "source activate" line should not be needed
source /opt/conda/bin/activate rapids
#conda env update --quiet --name=rapids --file=/rapids/cudf/conda/environments/cudf_dev_cuda${CUDA_VERSION}.yml
# mwendt: add cupy install to match gpuci scripts
conda install -y -q -c conda-forge fastavro "rapidsai::cupy>=6.6.0,<8.0.0a0,!=7.1.0"
# FIXME: Install the master version of dask, distributed, and streamz
pip install "git+https://github.com/dask/distributed.git" --upgrade --no-deps
pip install "git+https://github.com/dask/dask.git" --upgrade --no-deps
pip install "git+https://github.com/python-streamz/streamz.git" --upgrade --no-deps
env
conda list

TESTRESULTS_DIR=${WORKSPACE}/testresults
mkdir -p ${TESTRESULTS_DIR}
SUITEERROR=0

# build gtests
pushd /rapids/cudf/cpp/build
make build_tests_nvstrings
SUITEERROR=$((SUITEERROR | $?))
make build_tests_cudf
SUITEERROR=$((SUITEERROR | $?))
popd

# run gtests
for gt in /rapids/cudf/cpp/build/gtests/*; do
   ${gt} --gtest_output=xml:${TESTRESULTS_DIR}/
   exitcode=$?
   if (( ${exitcode} != 0 )); then
      SUITEERROR=${exitcode}
      echo "FAILED: ${gt}"
   fi
done

# Python tests
export PYTHONPATH=\
/rapids/cudf/python/cudf:\
/rapids/cudf/python/dask_cudf:\
/rapids/cudf/python/custreamz:\
/rapids/cudf/python/nvstrings:\
${PYTHONPATH}
py.test --junitxml=${TESTRESULTS_DIR}/pytest-cudf.xml -v /rapids/cudf/python/cudf/cudf/tests /rapids/cudf/python/dask_cudf/dask_cudf/tests
exitcode=$?
if (( ${exitcode} != 0 )); then
   SUITEERROR=${exitcode}
   echo "FAILED: 1 or more python tests"
fi

# FIXME: nvstrings tests should not need to depend on a speacific CWD
cd /rapids/cudf/python/nvstrings
# mwendt: need to output this to different file from above otherwise it clobbers the results
# mwendt: also removed specifying the `tests` directory to match gpuci scripts
py.test --junitxml=${TESTRESULTS_DIR}/pytest-nvstrings.xml -v
exitcode=$?
if (( ${exitcode} != 0 )); then
   SUITEERROR=${exitcode}
   echo "FAILED: 1 or more python tests"
fi

# mwendt: adding custreamz tests
cd /rapids/cudf/python/custreamz
py.test --junitxml=${TESTRESULTS_DIR}/pytest-custreamz.xml -v
exitcode=$?
if (( ${exitcode} != 0 )); then
   SUITEERROR=${exitcode}
   echo "FAILED: 1 or more python tests"
fi

exit ${SUITEERROR}
