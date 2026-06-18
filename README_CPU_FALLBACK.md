# Lab 16 GCP CPU Fallback: LightGBM on n2-standard-8

This path is for GCP projects where GPU quota or approval is not available yet. It still demonstrates the required lifecycle: Terraform IaC, private Cloud VM, IAP SSH, benchmark/training, inference metrics, billing evidence, and cleanup.

## Prerequisites

- Google Cloud CLI, Terraform, and Python installed locally.
- Billing enabled on the selected GCP project.
- Compute Engine and IAM APIs enabled.
- Kaggle API token available only for the VM, not committed to Git.

PowerShell environment variables:

```powershell
$env:TF_VAR_project_id="<PROJECT_ID>"
$env:TF_VAR_machine_type="n2-standard-8"
$env:TF_VAR_gpu_count="0"
$env:TF_VAR_hf_token="dummy"
```

Bash equivalent:

```bash
export TF_VAR_project_id="<PROJECT_ID>"
export TF_VAR_machine_type="n2-standard-8"
export TF_VAR_gpu_count="0"
export TF_VAR_hf_token="dummy"
```

## Authenticate And Enable APIs

```powershell
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>
gcloud services enable compute.googleapis.com iam.googleapis.com
gcloud services list --enabled --filter="name:(compute.googleapis.com OR iam.googleapis.com)"
```

## Terraform Deploy

From the repo root:

```powershell
terraform -chdir=terraform-gcp init
terraform -chdir=terraform-gcp fmt
terraform -chdir=terraform-gcp validate
terraform -chdir=terraform-gcp plan
```

Before apply, review the plan. This creates paid resources: a private `n2-standard-8` VM, VPC, subnet, firewall rules, Cloud Router, Cloud NAT, instance group, health check, backend service, URL map, HTTP proxy, and global forwarding rule/load balancer IP.

```powershell
terraform -chdir=terraform-gcp apply
```

## SSH And Run Benchmark

Get the IAP command:

```powershell
terraform -chdir=terraform-gcp output iap_ssh_command
```

Copy benchmark files to the VM:

```powershell
$instance = terraform -chdir=terraform-gcp output -raw instance_name
$zone = terraform -chdir=terraform-gcp output -raw instance_zone
gcloud compute ssh $instance --zone=$zone --tunnel-through-iap --project=$env:TF_VAR_project_id --command="mkdir -p ~/ml-benchmark"
gcloud compute scp benchmark.py "${instance}:~/ml-benchmark/benchmark.py" --zone=$zone --tunnel-through-iap --project=$env:TF_VAR_project_id
gcloud compute scp terraform-gcp/scripts/run_cpu_benchmark.sh "${instance}:~/ml-benchmark/run_cpu_benchmark.sh" --zone=$zone --tunnel-through-iap --project=$env:TF_VAR_project_id
```

Set up Kaggle credentials on the VM only:

1. Kaggle -> Settings -> API Tokens / Legacy API Credentials -> Create New Token.
2. Put the downloaded `kaggle.json` only at `~/.kaggle/kaggle.json` on the VM.
3. Run `chmod 600 ~/.kaggle/kaggle.json`.
4. Do not commit `kaggle.json`, paste it into Terraform, or place it in tracked files.

Run the benchmark:

```powershell
gcloud compute ssh $instance --zone=$zone --tunnel-through-iap --project=$env:TF_VAR_project_id --command="bash ~/ml-benchmark/run_cpu_benchmark.sh"
```

Manual dataset command if needed on the VM:

```bash
mkdir -p ~/.kaggle
chmod 600 ~/.kaggle/kaggle.json
kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p ~/ml-benchmark/
```

## Evidence Collection

After benchmark completes and before destroy:

```powershell
New-Item -ItemType Directory -Force evidence
$instance = terraform -chdir=terraform-gcp output -raw instance_name
$zone = terraform -chdir=terraform-gcp output -raw instance_zone
gcloud compute scp "${instance}:~/ml-benchmark/benchmark_terminal_output.txt" evidence/benchmark_terminal_output.txt --zone=$zone --tunnel-through-iap --project=$env:TF_VAR_project_id
gcloud compute scp "${instance}:~/ml-benchmark/benchmark_result.json" evidence/benchmark_result.json --zone=$zone --tunnel-through-iap --project=$env:TF_VAR_project_id
terraform -chdir=terraform-gcp output > evidence/terraform_output.txt
terraform -chdir=terraform-gcp state list > evidence/terraform_state_list.txt
gcloud compute instances list --project=$env:TF_VAR_project_id > evidence/gcloud_instances_before_destroy.txt
gcloud compute forwarding-rules list --project=$env:TF_VAR_project_id > evidence/gcloud_forwarding_rules_before_destroy.txt
gcloud compute routers list --project=$env:TF_VAR_project_id > evidence/gcloud_routers_before_destroy.txt
gcloud compute addresses list --project=$env:TF_VAR_project_id > evidence/gcloud_addresses_before_destroy.txt
```

Create `evidence/final_report_vi.md` using the actual metrics in `evidence/benchmark_result.json`. Do not invent metrics. The helper script does this automatically after copying the benchmark files:

```powershell
.\scripts\collect_cpu_evidence.ps1 -ProjectId $env:TF_VAR_project_id
```

The helper builds `lab16_cpu_evidence.zip` from a clean staging folder. Before submitting, verify the zip does not include `.terraform/`, `*.tfstate`, `.env`, `kaggle.json`, Hugging Face tokens, Google credentials, or any secret/token files.

## Screenshot Checklist

Take screenshots before destroying resources:

1. Terminal showing `python3 benchmark.py` output with all metrics.
2. `benchmark_result.json` contents.
3. GCP Console -> Billing -> Reports showing Compute Engine, Cloud NAT, and Load Balancing cost.
4. GCP Console -> Compute Engine -> VM instances showing the Terraform CPU VM.
5. Terraform source folder or `lab16_cpu_evidence.zip`.

## Cleanup

Do not leave resources running after screenshots are saved:

```powershell
terraform -chdir=terraform-gcp destroy
gcloud compute instances list --project=$env:TF_VAR_project_id
gcloud compute forwarding-rules list --project=$env:TF_VAR_project_id
gcloud compute routers list --project=$env:TF_VAR_project_id
gcloud compute addresses list --project=$env:TF_VAR_project_id
```

## Why CPU Fallback Is Acceptable

GPU quota/approval was not available in time. The CPU fallback still validates the full infrastructure workflow from Terraform to VM execution, benchmark metrics, billing checks, and cleanup. For LightGBM on tabular data, CPU is a suitable infrastructure choice because the workload is CPU-friendly and avoids GPU quota blockers.
