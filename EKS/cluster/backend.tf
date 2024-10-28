
terraform {
  backend "s3" {
    bucket = "tfm-state-storage-bharath-mumbai20241028140116376600000001"
    key = "eks"
    dynamodb_table = "tfm-state-storage-bharath-mumbai"
    region = "ap-south-1"
  }
}