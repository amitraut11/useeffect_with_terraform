resource "aws_codebuild_project" "tf-plan" {
  name         = "tf-cicd-plan"
  description  = "Plan stage for terraform"
  service_role = aws_iam_role.tf-codebuild-role-terraform.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:0.14.3"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential {
      credential          = var.dockerhub_credentials
      credential_provider = "SECRETS_MANAGER"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec/plan-buildspec.yml")
  }
}

resource "aws_codebuild_project" "tf-apply" {
  name         = "tf-cicd-apply"
  description  = "Apply stage for terraform"
  service_role = aws_iam_role.tf-codebuild-role-terraform.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:1.4.4"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential {
      credential          = var.dockerhub_credentials
      credential_provider = "SECRETS_MANAGER"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec/apply-buildspec.yml")
  }
}

resource "aws_codebuild_project" "tf-image" {
  name          = "tf-cicd-image"
  description   = "Builds a Docker image and pushes it to ECR"
  build_timeout = 60
  service_role  = aws_iam_role.tf-codebuild-role-terraform.arn

  source {
    type      = "CODEPIPELINE"
    buildspec = file("buildspec/image-buildspec.yml")
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0" # Docker image with Terraform and other tools
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    #image_pull_credentials_type = "SERVICE_ROLE"
    environment_variable {
      name  = "DOCKER_REPO"
      value = "https://hub.docker.com/u/amitraut11" # Replace with your Docker repository URL
    }
    # registry_credential{
    #     credential = var.dockerhub_credentials
    #     credential_provider = "SECRETS_MANAGER"
    # }
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}




resource "aws_codepipeline" "cicd_pipeline" {

  name     = "tf-cicd"
  role_arn = aws_iam_role.tf-codepipeline-role-terraform.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline-artifacts-firstreactapp.id
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["tf-code"]
      configuration = {
        FullRepositoryId     = "amitraut11/useeffect_with_terraform"
        BranchName           = "main"
        ConnectionArn        = var.codestar_connector_credentials
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "true"
      }
    }
  }

  stage {
    name = "Plan"
    action {
      name            = "Build"
      category        = "Build"
      provider        = "CodeBuild"
      version         = "1"
      owner           = "AWS"
      input_artifacts = ["tf-code"]
      configuration = {
        ProjectName = "tf-cicd-plan"
      }
    }
  }

  stage {
    name = "Image"
    action {
      name            = "Image"
      category        = "Build"
      provider        = "CodeBuild"
      version         = "1"
      owner           = "AWS"
      input_artifacts = ["tf-code"]
      configuration = {
        ProjectName = "tf-cicd-image"
      }
    }
  }

  stage {
    name = "Apply"
    action {
      name            = "Deploy"
      category        = "Build"
      provider        = "CodeBuild"
      version         = "1"
      owner           = "AWS"
      input_artifacts = ["tf-code"]
      configuration = {
        ProjectName = "tf-cicd-apply"
      }
    }
  }





}









//creatte a role for codepipeline
resource "aws_iam_role" "tf-codepipeline-role-terraform" {
  name = "tf-codepipeline-role-terraform"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

//create a policy document for pipeline
data "aws_iam_policy_document" "tf-cicd-pipeline-policies-terraform" {
  statement {
    sid       = ""
    actions   = ["codestar-connections:UseConnection"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    sid       = ""
    actions   = ["cloudwatch:*", "s3:*", "codebuild:*"]
    resources = ["*"]
    effect    = "Allow"
  }
}

// create a policy for codepipeline role
resource "aws_iam_policy" "tf-cicd-pipeline-policy-terraform" {
  name        = "tf-cicd-pipeline-policy-terraform"
  path        = "/"
  description = "Pipeline policy"
  policy      = data.aws_iam_policy_document.tf-cicd-pipeline-policies-terraform.json
}

//attach a codepipeline policy to role
resource "aws_iam_role_policy_attachment" "tf-cicd-pipeline-attachment" {
  policy_arn = aws_iam_policy.tf-cicd-pipeline-policy-terraform.arn
  role       = aws_iam_role.tf-codepipeline-role-terraform.id
}

//create a iam role for codebuild
resource "aws_iam_role" "tf-codebuild-role-terraform" {
  name = "tf-codebuild-role-terraform"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

//create a policy document for codebuild
data "aws_iam_policy_document" "tf-cicd-build-policies-terraform" {
  statement {
    sid       = ""
    actions   = ["logs:*", "s3:*", "codebuild:*", "secretsmanager:*", "iam:*"]
    resources = ["*"]
    effect    = "Allow"
  }
  statement {
    sid = ""
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:ListTagsForResource",
      "ecr:DescribeImageScanFindings",
      "s3:GetObject",
      "s3:PutObject"

    ]
    resources = ["*"]
    effect    = "Allow"
  }

}


//create a policy for codebuild
resource "aws_iam_policy" "tf-cicd-build-policy-terraform" {
  name        = "tf-cicd-build-policy-terraform"
  path        = "/"
  description = "Codebuild policy"
  policy      = data.aws_iam_policy_document.tf-cicd-build-policies-terraform.json
}

//attach policy to codebuild role
resource "aws_iam_role_policy_attachment" "tf-cicd-codebuild-attachment-terraform11" {
  policy_arn = aws_iam_policy.tf-cicd-build-policy-terraform.arn
  role       = aws_iam_role.tf-codebuild-role-terraform.id
}

resource "aws_iam_role_policy_attachment" "tf-cicd-codebuild-attachment-terraform12" {
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  role       = aws_iam_role.tf-codebuild-role-terraform.id
}


//for ecs
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
