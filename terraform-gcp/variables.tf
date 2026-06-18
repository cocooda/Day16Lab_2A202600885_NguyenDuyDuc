variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "hf_token" {
  description = "Hugging Face token for GPU/vLLM mode. Use dummy for CPU fallback."
  type        = string
  sensitive   = true
  default     = "dummy"
}

variable "model_id" {
  description = "Hugging Face Model ID to serve"
  type        = string
  default     = "google/gemma-4-E2B-it"
}

variable "machine_type" {
  description = "GCE machine type. Use n2-standard-8 for CPU fallback."
  type        = string
  default     = "n2-standard-8"
}

variable "gpu_type" {
  description = "GPU accelerator type"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "Number of GPUs to attach. Set to 0 for CPU fallback."
  type        = number
  default     = 0

  validation {
    condition     = var.gpu_count >= 0
    error_message = "gpu_count must be 0 or greater."
  }
}
