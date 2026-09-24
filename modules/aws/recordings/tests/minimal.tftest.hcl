mock_provider "aws" {}
variables { bucket_name = "aira-mocked-recordings-test" }
run "private_versioned_storage" {
  command = plan
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls && aws_s3_bucket_public_access_block.this.block_public_policy && aws_s3_bucket_public_access_block.this.ignore_public_acls && aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "All S3 public-access protections must remain enabled."
  }
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled" && !aws_s3_bucket.this.force_destroy
    error_message = "Recordings need versioning and protection from force deletion."
  }
  assert {
    condition     = length(aws_iam_role_policy_attachment.writer) == 0
    error_message = "Do not grant application access before trusted writer roles are supplied."
  }
}
