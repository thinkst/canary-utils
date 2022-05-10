terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

provider "google" {
  credentials = file("<YOUR SERVICE ACCOUNT CREDENTIALS.JSON>")

  project = "<YOUR PROJECT>"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_instance" "default" {
  name         = "mybird"
  zone         = "europe-west1-b"
  machine_type = "n1-standard-1"
  project      = "<YOUR PROJECT>"

  boot_disk {
    initialize_params {
      image = "thinkst-canary-ABC123/thinkst-canary"
    }
  }

  network_interface {
    network = "default"
  }

}