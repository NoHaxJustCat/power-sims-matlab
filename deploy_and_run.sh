#!/bin/bash
# deploy_and_run.sh — run this on your CLIENT

SERVER="nicolobasso@aurora-server"
REMOTE_DIR="~/jobs"

echo "--- Pushing files ---"
scp run_simulation.m run_matlab.sh $SERVER:$REMOTE_DIR/

echo "--- Submitting job ---"
JOB_ID=$(ssh $SERVER "cd $REMOTE_DIR && mkdir -p logs && sbatch run_matlab.sh" | awk '{print $4}')
echo "Job ID: $JOB_ID"

echo "--- Waiting for job to finish ---"
while ssh $SERVER "squeue -j $JOB_ID" 2>/dev/null | grep -q $JOB_ID; do
    echo "Still running... $(date)"
    sleep 30
done

echo "--- Pulling results ---"
scp $SERVER:$REMOTE_DIR/simulation_results.mat ./

echo "--- Done! Now run plot_results.m in MATLAB ---"
