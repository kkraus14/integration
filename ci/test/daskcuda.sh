#!/bin/bash
set +e
set -x
# FIXME: "source activate" line should not be needed
source /opt/conda/bin/activate rapids
# FIXME: should this be in the container?
# mwendt: this needs to be installed from `rapidsai` to keep the correct NCCL version already in the container
#         cupy right now is only needed for testing so that is why cudf/daskcuda install it separately in their ci/gpu/build.sh
conda install -y rapidsai::cupy
env
conda list

# mwendt: crucial redirect missing https://github.com/rapidsai/dask-cuda/blob/39eac0235a84dfd36ac0170e60a4cb3fdde17f47/ci/gpu/build.sh#L21
export HOME=$WORKSPACE 

TESTRESULTS_DIR=${WORKSPACE}/testresults
mkdir -p ${TESTRESULTS_DIR}
SUITEERROR=0

# Install distributed@master (temporarily required due to issues with 2.3.2)
pip install git+https://github.com/dask/distributed.git@master
pip install pytest-asyncio fsspec

# Python tests
cd /rapids/dask-cuda/dask_cuda
py.test --junitxml=${TESTRESULTS_DIR}/pytest.xml -v 
exitcode=$?
if (( ${exitcode} != 0 )); then
   SUITEERROR=${exitcode}
   echo "FAILED: 1 or more tests in /rapids/dask-cuda/dask_cuda/tests"
fi

exit ${SUITEERROR}
