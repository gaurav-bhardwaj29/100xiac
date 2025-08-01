# bucket store website

resource "google_storage_bucket" "landing" {
    name = var.bucket_name
    location = var.bucket_location
}

# make website public

resource "google_storage_object_access_control" "public_rule" {
    object = google_storage_bucket_object.static_page.name
    bucket = google_storage_bucket.landing.name
    role = "READER"
    entity = "allUsers"
}

# upload html file to bucket

resource "google_storage_bucket_object" "static_page" {
    name = "index.html"
    source = "./website/index.html"
    bucket = google_storage_bucket.landing.name
}

