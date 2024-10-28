module "state_storage" {
  source = "../modules/terraform-backend"

  aws_kms_alias                       = "tfm-state-storage-bharath-mumbai"
  tf_state_storage_bucket_name        = "tfm-state-storage-bharath-mumbai"
  tf_state_storage_dynamodb_lock_name = "tfm-state-storage-bharath-mumbai"
  aws_account_id                      = data.aws_caller_identity.current.account_id
}
