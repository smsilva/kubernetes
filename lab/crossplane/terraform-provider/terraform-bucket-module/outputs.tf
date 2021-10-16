output "name" {
  value = google_storage_bucket.default.id
}

output "url" {
  value = google_storage_bucket.default.self_link
}
