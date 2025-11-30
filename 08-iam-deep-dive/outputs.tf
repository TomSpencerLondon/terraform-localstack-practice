# ============================================================
# OUTPUTS
# ============================================================

# Users
output "users" {
  description = "IAM Users"
  value = {
    alice = {
      name = aws_iam_user.alice.name
      arn  = aws_iam_user.alice.arn
    }
    bob = {
      name = aws_iam_user.bob.name
      arn  = aws_iam_user.bob.arn
    }
    charlie = {
      name = aws_iam_user.charlie.name
      arn  = aws_iam_user.charlie.arn
    }
  }
}

# Groups
output "groups" {
  description = "IAM Groups"
  value = {
    developers = {
      name    = aws_iam_group.developers.name
      members = ["alice", "bob"]
      policy  = aws_iam_policy.developer_access.name
    }
    read_only = {
      name    = aws_iam_group.read_only.name
      members = ["charlie"]
      policy  = aws_iam_policy.read_only_access.name
    }
  }
}

# Roles
output "roles" {
  description = "IAM Roles"
  value = {
    lambda_execution = {
      name = aws_iam_role.lambda_execution.name
      arn  = aws_iam_role.lambda_execution.arn
      trusted_service = "lambda.amazonaws.com"
    }
    api_gateway = {
      name = aws_iam_role.api_gateway.name
      arn  = aws_iam_role.api_gateway.arn
      trusted_service = "apigateway.amazonaws.com"
    }
    ec2_instance = {
      name = aws_iam_role.ec2_instance.name
      arn  = aws_iam_role.ec2_instance.arn
      trusted_service = "ec2.amazonaws.com"
      instance_profile = aws_iam_instance_profile.ec2_instance.name
    }
  }
}

# Policies
output "policies" {
  description = "IAM Policies"
  value = {
    developer_access = {
      name = aws_iam_policy.developer_access.name
      arn  = aws_iam_policy.developer_access.arn
    }
    read_only_access = {
      name = aws_iam_policy.read_only_access.name
      arn  = aws_iam_policy.read_only_access.arn
    }
    deny_dangerous = {
      name = aws_iam_policy.deny_dangerous_actions.name
      arn  = aws_iam_policy.deny_dangerous_actions.arn
    }
    conditional = {
      name = aws_iam_policy.conditional_access.name
      arn  = aws_iam_policy.conditional_access.arn
    }
  }
}

# Example commands
output "example_commands" {
  description = "Useful IAM CLI commands"
  value = <<-EOT

    # ============================================================
    # IAM USER COMMANDS
    # ============================================================

    # List all users
    awslocal iam list-users

    # Get user details
    awslocal iam get-user --user-name alice

    # List groups for a user
    awslocal iam list-groups-for-user --user-name alice

    # ============================================================
    # IAM GROUP COMMANDS
    # ============================================================

    # List all groups
    awslocal iam list-groups

    # Get group members
    awslocal iam get-group --group-name developers

    # List policies attached to group
    awslocal iam list-attached-group-policies --group-name developers

    # ============================================================
    # IAM ROLE COMMANDS
    # ============================================================

    # List all roles
    awslocal iam list-roles

    # Get role details (including trust policy)
    awslocal iam get-role --role-name ${aws_iam_role.lambda_execution.name}

    # List policies attached to role
    awslocal iam list-role-policies --role-name ${aws_iam_role.lambda_execution.name}

    # ============================================================
    # IAM POLICY COMMANDS
    # ============================================================

    # List all policies
    awslocal iam list-policies --scope Local

    # Get policy details
    awslocal iam get-policy --policy-arn ${aws_iam_policy.developer_access.arn}

    # Get policy document (the actual JSON)
    awslocal iam get-policy-version \
      --policy-arn ${aws_iam_policy.developer_access.arn} \
      --version-id v1

  EOT
}
