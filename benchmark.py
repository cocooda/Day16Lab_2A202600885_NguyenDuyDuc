#!/usr/bin/env python3
"""LightGBM CPU benchmark for Lab 16 GCP fallback."""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any


REQUIRED_METRICS = (
    "data_load_time_seconds",
    "training_time_seconds",
    "best_iteration",
    "auc_roc",
    "accuracy",
    "f1_score",
    "precision",
    "recall",
    "inference_latency_1_row_ms",
    "inference_throughput_1000_rows_per_second",
)


def missing_dataset_message(dataset_path: Path) -> str:
    return f"""Dataset not found: {dataset_path}

Download the Credit Card Fraud Detection dataset on the VM:

  mkdir -p ~/.kaggle
  # Put Kaggle API credentials only in ~/.kaggle/kaggle.json on the VM.
  chmod 600 ~/.kaggle/kaggle.json
  mkdir -p ~/ml-benchmark
  kaggle datasets download -d mlg-ulb/creditcardfraud --unzip -p ~/ml-benchmark/

Do not commit kaggle.json or paste Kaggle credentials into tracked files.
"""


def write_results(metrics: dict[str, Any], output_path: Path) -> None:
    output_path.write_text(
        json.dumps(metrics, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _import_dependencies():
    missing_help = (
        "Missing Python packages. Install them with:\n"
        "  python3 -m pip install --user lightgbm scikit-learn pandas numpy"
    )
    try:
        import lightgbm as lgb
        import numpy as np
        import pandas as pd
        from sklearn.metrics import (
            accuracy_score,
            f1_score,
            precision_score,
            recall_score,
            roc_auc_score,
        )
        from sklearn.model_selection import train_test_split
    except ImportError as exc:
        raise RuntimeError(f"{missing_help}\n\nOriginal import error: {exc}") from exc

    return {
        "lgb": lgb,
        "np": np,
        "pd": pd,
        "accuracy_score": accuracy_score,
        "f1_score": f1_score,
        "precision_score": precision_score,
        "recall_score": recall_score,
        "roc_auc_score": roc_auc_score,
        "train_test_split": train_test_split,
    }


def run_benchmark(dataset_path: Path, output_path: Path, seed: int = 42) -> dict[str, Any]:
    if not dataset_path.exists():
        raise FileNotFoundError(missing_dataset_message(dataset_path))

    deps = _import_dependencies()
    lgb = deps["lgb"]
    np = deps["np"]
    pd = deps["pd"]

    load_start = time.perf_counter()
    data = pd.read_csv(dataset_path)
    data_load_time = time.perf_counter() - load_start

    if "Class" not in data.columns:
        raise ValueError("Dataset must contain a 'Class' target column.")

    x = data.drop(columns=["Class"])
    y = data["Class"].astype(int)

    train_test_split = deps["train_test_split"]
    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=seed,
        stratify=y,
    )

    x_train, x_valid, y_train, y_valid = train_test_split(
        x_train,
        y_train,
        test_size=0.2,
        random_state=seed,
        stratify=y_train,
    )

    model = lgb.LGBMClassifier(
        objective="binary",
        n_estimators=300,
        learning_rate=0.05,
        num_leaves=31,
        subsample=0.85,
        colsample_bytree=0.85,
        class_weight="balanced",
        random_state=seed,
        n_jobs=-1,
        verbosity=-1,
    )

    train_start = time.perf_counter()
    model.fit(
        x_train,
        y_train,
        eval_set=[(x_valid, y_valid)],
        eval_metric="auc",
        callbacks=[lgb.early_stopping(25, verbose=False)],
    )
    training_time = time.perf_counter() - train_start

    probabilities = model.predict_proba(x_test)[:, 1]
    predictions = (probabilities >= 0.5).astype(int)

    one_row = x_test.iloc[[0]]
    latency_start = time.perf_counter()
    model.predict_proba(one_row)
    latency_ms = (time.perf_counter() - latency_start) * 1000

    sample_size = min(1000, len(x_test))
    sample = x_test.iloc[:sample_size]
    throughput_start = time.perf_counter()
    model.predict_proba(sample)
    throughput_seconds = max(time.perf_counter() - throughput_start, 1e-9)
    throughput = sample_size / throughput_seconds

    best_iteration = getattr(model, "best_iteration_", None)
    if best_iteration is None or best_iteration <= 0:
        best_iteration = int(model.n_estimators)

    metrics = {
        "data_load_time_seconds": round(float(data_load_time), 4),
        "training_time_seconds": round(float(training_time), 4),
        "best_iteration": int(best_iteration),
        "auc_roc": round(float(deps["roc_auc_score"](y_test, probabilities)), 6),
        "accuracy": round(float(deps["accuracy_score"](y_test, predictions)), 6),
        "f1_score": round(float(deps["f1_score"](y_test, predictions, zero_division=0)), 6),
        "precision": round(float(deps["precision_score"](y_test, predictions, zero_division=0)), 6),
        "recall": round(float(deps["recall_score"](y_test, predictions, zero_division=0)), 6),
        "inference_latency_1_row_ms": round(float(latency_ms), 4),
        "inference_throughput_1000_rows_per_second": round(float(throughput), 2),
    }

    write_results(metrics, output_path)
    return metrics


def print_summary(metrics: dict[str, Any], output_path: Path) -> None:
    print("")
    print("LAB 16 CPU FALLBACK LIGHTGBM BENCHMARK")
    print("======================================")
    print(f"Data load time:        {metrics['data_load_time_seconds']} s")
    print(f"Training time:         {metrics['training_time_seconds']} s")
    print(f"Best iteration:        {metrics['best_iteration']}")
    print(f"AUC-ROC:               {metrics['auc_roc']}")
    print(f"Accuracy:              {metrics['accuracy']}")
    print(f"F1-score:              {metrics['f1_score']}")
    print(f"Precision:             {metrics['precision']}")
    print(f"Recall:                {metrics['recall']}")
    print(f"1-row latency:         {metrics['inference_latency_1_row_ms']} ms")
    print(
        "1000-row throughput:   "
        f"{metrics['inference_throughput_1000_rows_per_second']} rows/s"
    )
    print(f"Result JSON:           {output_path}")
    print("======================================")
    print("")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the Lab 16 LightGBM CPU benchmark.")
    parser.add_argument("--data", default="creditcard.csv", help="Path to creditcard.csv")
    parser.add_argument(
        "--output",
        default="benchmark_result.json",
        help="Path for benchmark_result.json",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    dataset_path = Path(args.data).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()

    try:
        metrics = run_benchmark(dataset_path, output_path)
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 2
    except (RuntimeError, ValueError) as exc:
        print(exc, file=sys.stderr)
        return 1

    print_summary(metrics, output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
