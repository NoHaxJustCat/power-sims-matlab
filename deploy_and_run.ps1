param(
    [ValidateSet('all','point','axis')]
    [string]$Jobs = 'all'
)

$REMOTE = "nbasso@aurora-server"
$REMOTE_DIR = "~/matlab_jobs/power_sims"
$LOCAL_FILES = @("main_point.m", "main_axis.m", "submit_point.sh", "submit_axis.sh")
$LOCAL_DIRS = @("lib")

Write-Host "==> Syncing files..."
ssh $REMOTE "mkdir -p $REMOTE_DIR/results $REMOTE_DIR/logs $REMOTE_DIR/lib $REMOTE_DIR/out"
foreach ($file in $LOCAL_FILES) {
    scp $file "${REMOTE}:${REMOTE_DIR}/"
}
foreach ($dir in $LOCAL_DIRS) {
    scp -r $dir "${REMOTE}:${REMOTE_DIR}/"
}

Write-Host "==> Fixing line endings..."
ssh $REMOTE "sed -i 's/\r//' $REMOTE_DIR/submit_point.sh $REMOTE_DIR/submit_axis.sh"

$JOB_ID_POINT = $null
$JOB_ID_AXIS = $null

if ($Jobs -in @('all', 'point')) {
    Write-Host "==> Submitting point SLURM job..."
    $JOB_OUTPUT_POINT = ssh $REMOTE "cd $REMOTE_DIR && sbatch submit_point.sh"
    Write-Host "    sbatch point output: $JOB_OUTPUT_POINT"
    if ($JOB_OUTPUT_POINT -match "Submitted batch job (\d+)") {
        $JOB_ID_POINT = $Matches[1]
        Write-Host "    Point Job ID: $JOB_ID_POINT"
    } else {
        Write-Host "    ERROR: sbatch point failed."
        exit 1
    }
}

if ($Jobs -in @('all', 'axis')) {
    Write-Host "==> Submitting axis SLURM job..."
    $JOB_OUTPUT_AXIS = ssh $REMOTE "cd $REMOTE_DIR && sbatch submit_axis.sh"
    Write-Host "    sbatch axis output: $JOB_OUTPUT_AXIS"
    if ($JOB_OUTPUT_AXIS -match "Submitted batch job (\d+)") {
        $JOB_ID_AXIS = $Matches[1]
        Write-Host "    Axis Job ID: $JOB_ID_AXIS"
    } else {
        Write-Host "    ERROR: sbatch axis failed."
        exit 1
    }
}

Write-Host "==> Waiting for jobs to complete..."
do {
    Start-Sleep -Seconds 10
    $numRunning = 0

    if ($JOB_ID_POINT) {
        $QUEUE_POINT = ssh $REMOTE "squeue -j $JOB_ID_POINT 2>/dev/null"
        if ($QUEUE_POINT -match $JOB_ID_POINT) { $numRunning++ }
    }

    if ($JOB_ID_AXIS) {
        $QUEUE_AXIS = ssh $REMOTE "squeue -j $JOB_ID_AXIS 2>/dev/null"
        if ($QUEUE_AXIS -match $JOB_ID_AXIS) { $numRunning++ }
    }

    if ($numRunning -gt 0) {
        Write-Host "    $numRunning job(s) still running..."
    }
} while ($numRunning -gt 0)
Write-Host "    Jobs done."

Write-Host "==> Retrieving results..."
New-Item -ItemType Directory -Force -Path .\results | Out-Null
New-Item -ItemType Directory -Force -Path .\out | Out-Null

if ($Jobs -in @('all', 'point')) {
    scp "${REMOTE}:${REMOTE_DIR}/results/directional_results*.mat" ".\results\"
}
if ($Jobs -in @('all', 'axis')) {
    scp "${REMOTE}:${REMOTE_DIR}/results/axis_results*.mat" ".\results\"
}
scp "${REMOTE}:${REMOTE_DIR}/out/*.png" ".\out\"

Write-Host "    Done. Results in .\results\ and plots in .\out\"