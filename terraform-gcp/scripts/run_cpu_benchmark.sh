#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/ml-benchmark}"
SCRIPT_SOURCE="${SCRIPT_SOURCE:-$WORKDIR/benchmark.py}"
LOG_FILE="$WORKDIR/benchmark_terminal_output.txt"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv unzip
python3 -m venv "$WORKDIR/.venv"
"$WORKDIR/.venv/bin/python" -m pip install --upgrade pip
"$WORKDIR/.venv/bin/python" -m pip install lightgbm scikit-learn pandas numpy kaggle

if [ ! -f "$SCRIPT_SOURCE" ]; then
  echo "benchmark.py not found at $SCRIPT_SOURCE"
  echo "Copy it from your local machine first, for example:"
  echo "  gcloud compute scp ../benchmark.py \$(terraform -chdir=terraform-gcp output -raw instance_name):~/ml-benchmark/ --zone=\$(terraform -chdir=terraform-gcp output -raw instance_zone) --tunnel-through-iap"
  exit 1
fi

if [ ! -f "$WORKDIR/creditcard.csv" ]; then
  if [ -f "$HOME/.kaggle/kaggle.json" ]; then
    chmod 600 "$HOME/.kaggle/kaggle.json"
    "$WORKDIR/.venv/bin/kaggle" datasets download -d mlg-ulb/creditcardfraud --unzip -p "$WORKDIR"
  else
    echo "Kaggle credentials not found at ~/.kaggle/kaggle.json"
    echo "Create ~/.kaggle/kaggle.json on the VM and run:"
    echo "  chmod 600 ~/.kaggle/kaggle.json"
    echo "  kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p ~/ml-benchmark/"
    exit 2
  fi
fi

"$WORKDIR/.venv/bin/python" "$SCRIPT_SOURCE" --data "$WORKDIR/creditcard.csv" --output "$WORKDIR/benchmark_result.json" 2>&1 | tee "$LOG_FILE"
