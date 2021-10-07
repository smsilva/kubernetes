output "bucket_id" {
  value = google_storage_bucket.default.id
}

output "bucket_url" {
  value = google_storage_bucket.default.self_link
}

output "instance" {
  value = google_storage_bucket.default
}
