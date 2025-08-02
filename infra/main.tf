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

# Get the managed DNS zone
data "google_dns_managed_zone" "gcp_coffeetime_dev" {
  provider = google
  name     = "seedawk-bearblog"
}

# Add the IP to the DNS
resource "google_dns_record_set" "landing" {
  provider     = google
  name         = "landing.${data.google_dns_managed_zone.gcp_coffeetime_dev.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.gcp_coffeetime_dev.name
  rrdatas      = [google_compute_global_address.landing.address]
}

# Add the bucket as a CDN backend

resource "google_compute_backend_bucket" "landing-backend" {
  provider    = google
  name        = "landing-backend"
  description = "Contains files needed by the website"
  bucket_name = google_storage_bucket.landing.name
  enable_cdn  = true
}

# Create HTTPS certificate

resource "google_compute_managed_ssl_certificate" "landing" {
  provider = google-beta
  name     = "landing-cert"
  managed {
    domains = [google_dns_record_set.landing.name]
  }
}

# GCP URL MAP

resource "google_compute_url_map" "landing" {
  provider        = google
  name            = "landing-url-map"
  default_service = google_compute_backend_bucket.landing-backend.self_link
    host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_bucket.landing-backend.self_link
  }
}

# GCP target proxy

resource "google_compute_target_https_proxy" "landing" {
  provider         = google
  name             = "landing-target-proxy"
  url_map          = google_compute_url_map.landing.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.landing.self_link]
}

# GCP forwarding rule

resource "google_compute_global_forwarding_rule" "default" {
  provider              = google
  name                  = "landing-forwarding-rule"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.landing.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.landing.self_link
}