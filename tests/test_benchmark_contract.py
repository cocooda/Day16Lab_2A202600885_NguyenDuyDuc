import json
import tempfile
import unittest
from pathlib import Path

import benchmark


class BenchmarkContractTests(unittest.TestCase):
    def test_missing_dataset_message_mentions_kaggle_setup(self):
        with tempfile.TemporaryDirectory() as tmp:
            dataset_path = Path(tmp) / "creditcard.csv"

            message = benchmark.missing_dataset_message(dataset_path)

            self.assertIn("creditcard.csv", message)
            self.assertIn("~/.kaggle/kaggle.json", message)
            self.assertIn("kaggle datasets download -d mlg-ulb/creditcardfraud", message)

    def test_write_results_creates_json_with_required_metrics(self):
        with tempfile.TemporaryDirectory() as tmp:
            output_path = Path(tmp) / "benchmark_result.json"
            metrics = {
                "data_load_time_seconds": 1.0,
                "training_time_seconds": 2.0,
                "best_iteration": 10,
                "auc_roc": 0.99,
                "accuracy": 0.98,
                "f1_score": 0.97,
                "precision": 0.96,
                "recall": 0.95,
                "inference_latency_1_row_ms": 0.1,
                "inference_throughput_1000_rows_per_second": 1234.5,
            }

            benchmark.write_results(metrics, output_path)

            saved = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertEqual(saved, metrics)


if __name__ == "__main__":
    unittest.main()
