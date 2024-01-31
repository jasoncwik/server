#!/bin/bash
# Copyright 2023-2024, NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

CLIENT_PY="../python_unittest.py"
CLIENT_LOG="./request_rescheduling_client.log"
TEST_RESULT_FILE='test_results.txt'
source ../../common/util.sh

if [[ ${TEST_WINDOWS} == 1 ]]; then
    pip install pytest numpy tritonclient[all]
fi

RET=0

rm -fr *.log ./models *.txt

mkdir -p models/bls_request_rescheduling/1/
cp ../../python_models/bls_request_rescheduling/model.py models/bls_request_rescheduling/1/
cp ../../python_models/bls_request_rescheduling/config.pbtxt models/bls_request_rescheduling

mkdir -p models/request_rescheduling_addsub/1/
cp ../../python_models/request_rescheduling_addsub/model.py models/request_rescheduling_addsub/1/
cp ../../python_models/request_rescheduling_addsub/config.pbtxt models/request_rescheduling_addsub

mkdir -p models/iterative_sequence/1/
cp ../../python_models/iterative_sequence/model.py models/iterative_sequence/1/
cp ../../python_models/iterative_sequence/config.pbtxt models/iterative_sequence

mkdir -p models/wrong_return_type/1/
cp ../../python_models/wrong_return_type/model.py models/wrong_return_type/1/
cp ../../python_models/wrong_return_type/config.pbtxt models/wrong_return_type

SERVER_LOG="./request_rescheduling_server.log"
SERVER_ARGS="--model-repository=${MODELDIR}/request_rescheduling/models --backend-directory=${BACKEND_DIR} --model-control-mode=explicit --load-model=* --log-verbose=1"

run_server
if [ "$SERVER_PID" == "0" ]; then
    echo -e "\n***\n*** Failed to start $SERVER\n***"
    cat $SERVER_LOG
    exit 1
fi

export MODEL_NAME='bls_request_rescheduling'

set +e
python3 -m pytest --junitxml="${MODEL_NAME}.report.xml" $CLIENT_PY >> $CLIENT_LOG 2>&1
if [ $? -ne 0 ]; then
    echo -e "\n***\n*** bls_request_rescheduling test FAILED. \n***"
    cat $CLIENT_LOG
    RET=1
fi
set -e

GRPC_TEST_PY=./grpc_endpoint_test.py

set +e
python3 -m pytest --junitxml="grpc_request_reschedule.report.xml" ${GRPC_TEST_PY} >> ${CLIENT_LOG} 2>&1
if [ $? -ne 0 ]; then
    echo -e "\n***\n*** GRPC Endpoint test FAILED. \n***"
    cat $CLIENT_LOG
    RET=1
fi
set -e

kill_server


if [ $RET -eq 1 ]; then
    cat $SERVER_LOG
    echo -e "\n***\n*** Request Rescheduling test FAILED. \n***"
else
    echo -e "\n***\n*** Request Rescheduling test PASSED. \n***"
fi

exit $RET
