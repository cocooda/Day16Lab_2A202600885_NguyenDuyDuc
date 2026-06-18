param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId
)

$ErrorActionPreference = "Stop"

$gcloud = "gcloud"
$defaultGcloud = "C:\Users\Admin\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
if (Test-Path $defaultGcloud) {
    $gcloud = $defaultGcloud
}
$env:Path += ";C:\Terraform"

New-Item -ItemType Directory -Force evidence | Out-Null

$instance = terraform -chdir=terraform-gcp output -raw instance_name
$zone = terraform -chdir=terraform-gcp output -raw instance_zone

& $gcloud compute scp "${instance}:/home/bachduc_june_gmail_com/ml-benchmark/benchmark_terminal_output.txt" evidence/benchmark_terminal_output.txt --zone=$zone --tunnel-through-iap --project=$ProjectId
& $gcloud compute scp "${instance}:/home/bachduc_june_gmail_com/ml-benchmark/benchmark_result.json" evidence/benchmark_result.json --zone=$zone --tunnel-through-iap --project=$ProjectId

terraform -chdir=terraform-gcp output | Out-File -Encoding utf8 evidence/terraform_output.txt
terraform -chdir=terraform-gcp state list | Out-File -Encoding utf8 evidence/terraform_state_list.txt
& $gcloud compute instances list --project=$ProjectId | Out-File -Encoding utf8 evidence/gcloud_instances_before_destroy.txt
& $gcloud compute forwarding-rules list --project=$ProjectId | Out-File -Encoding utf8 evidence/gcloud_forwarding_rules_before_destroy.txt
& $gcloud compute routers list --project=$ProjectId | Out-File -Encoding utf8 evidence/gcloud_routers_before_destroy.txt
& $gcloud compute addresses list --project=$ProjectId | Out-File -Encoding utf8 evidence/gcloud_addresses_before_destroy.txt

$metrics = Get-Content -Raw evidence/benchmark_result.json | ConvertFrom-Json
$report = @"
# Bao cao Lab 16 CPU fallback

GPU quota/approval khong san sang kip thoi, nen bai lab su dung CPU fallback voi LightGBM tren workload du lieu bang.
Quy trinh van chung minh day du vong doi ha tang: Terraform IaC -> Cloud VM -> benchmark/training -> inference metrics -> billing check -> cleanup.
Training time: $($metrics.training_time_seconds) giay.
AUC-ROC: $($metrics.auc_roc); accuracy: $($metrics.accuracy); F1-score: $($metrics.f1_score).
Precision: $($metrics.precision); recall: $($metrics.recall).
Inference latency 1 row: $($metrics.inference_latency_1_row_ms) ms.
Inference throughput 1000 rows: $($metrics.inference_throughput_1000_rows_per_second) rows/s.
Infrastructure conclusion: CPU phu hop hon cho fallback workload nay vi LightGBM/tabular training than thien voi CPU, tranh quota blocker cua GPU, giam rui ro setup, va van xac thuc duoc lifecycle ha tang cloud bat buoc.
"@
$report | Out-File -Encoding utf8 evidence/final_report_vi.md

Copy-Item evidence/benchmark_result.json benchmark_result.json -Force
if (Test-Path lab16_cpu_evidence.zip) {
    Remove-Item lab16_cpu_evidence.zip
}

$stage = Join-Path $env:TEMP "lab16_cpu_evidence_stage"
if (Test-Path $stage) {
    Remove-Item -Recurse -Force $stage
}
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item -Recurse evidence (Join-Path $stage "evidence")
Copy-Item benchmark.py (Join-Path $stage "benchmark.py")
Copy-Item benchmark_result.json (Join-Path $stage "benchmark_result.json")
Copy-Item README_CPU_FALLBACK.md (Join-Path $stage "README_CPU_FALLBACK.md")
New-Item -ItemType Directory -Force (Join-Path $stage "terraform-gcp") | Out-Null
Get-ChildItem terraform-gcp -File | Where-Object {
    $_.Name -notmatch '\.tfstate' -and
    $_.Name -notmatch '^tfplan' -and
    $_.Name -ne ".env" -and
    $_.Name -notmatch 'credential|token|kaggle'
} | Copy-Item -Destination (Join-Path $stage "terraform-gcp")
if (Test-Path terraform-gcp/scripts) {
    New-Item -ItemType Directory -Force (Join-Path $stage "terraform-gcp/scripts") | Out-Null
    Get-ChildItem terraform-gcp/scripts -File | Copy-Item -Destination (Join-Path $stage "terraform-gcp/scripts")
}
Compress-Archive -Force -Path (Join-Path $stage "*") -DestinationPath lab16_cpu_evidence.zip

Write-Host "Evidence collected in evidence/ and lab16_cpu_evidence.zip"
Write-Host "Verify the zip does not contain .terraform, tfstate, .env, kaggle.json, or credential files before submitting."
