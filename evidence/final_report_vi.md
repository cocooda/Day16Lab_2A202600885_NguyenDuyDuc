# Bao cao Lab 16 CPU fallback

GPU quota/approval khong san sang kip thoi, nen bai lab su dung CPU fallback voi LightGBM tren workload du lieu bang.
Quy trinh van chung minh day du vong doi ha tang: Terraform IaC -> Cloud VM -> benchmark/training -> inference metrics -> billing check -> cleanup.
Training time: 0.6076 giay.
AUC-ROC: 0.954958; accuracy: 0.993101; F1-score: 0.306878.
Precision: 0.185501; recall: 0.887755.
Inference latency 1 row: 1.2958 ms.
Inference throughput 1000 rows: 766409.2 rows/s.
Infrastructure conclusion: CPU phu hop hon cho fallback workload nay vi LightGBM/tabular training than thien voi CPU, tranh quota blocker cua GPU, giam rui ro setup, va van xac thuc duoc lifecycle ha tang cloud bat buoc.
