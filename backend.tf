terraform {
  backend "s3" {
    bucket       = "pentest-testing"
    key          = "pentest-testing/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}