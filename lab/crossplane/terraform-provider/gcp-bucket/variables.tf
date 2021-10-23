variable "prefix" {
  type        = string
  description = "Bucket Name Prefix. If set as 'generic-storage-1' then you should get something like: generic-storage-1-x5f"
  default     = "generic-bucket"
}

variable "location" {
  type        = string
  description = "Google Cloud Region"
  default     = "southamerica-east1"
}
