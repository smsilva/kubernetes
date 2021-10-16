variable "prefix" {
  type        = string
  description = "Bucket Name Prefix. If set as 'generic-storage-1' then you should get something like: generic-storage-1-x5f"
}

variable "location" {
  type        = string
  description = "Google Cloud Region"
}
