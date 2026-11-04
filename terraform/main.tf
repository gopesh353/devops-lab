terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

variable "replica_count" {
  description = "Number of scalable infrastructure instances to provision"
  type        = number
  default     = 3
}

resource "local_file" "infra_instances" {
  count    = var.replica_count
  filename = "${path.module}/instances/worker_${count.index + 1}.json"
  content  = jsonencode({
    instance_id   = "worker-${count.index + 1}"
    status        = "RUNNING"
    service       = "gemini-chatbot-cluster"
    node_tier     = "compute-optimized"
    provisioned_by = "Terraform-IaC"
  })
}

output "provisioned_nodes" {
  description = "List of scalable infrastructure instances provisioned"
  value       = [for instance in local_file.infra_instances : instance.filename]
}
