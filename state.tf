terraform {
  backend "s3" {
    bucket  = "firstreactapp-ts-terra-cp-cd-backend"
    encrypt = true
    key     = "terraform.tfstate"
    region  = "us-east-1"

  }
}

provider "aws" {
  region = "us-east-1"

}
