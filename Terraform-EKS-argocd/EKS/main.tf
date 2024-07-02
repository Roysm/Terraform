# This Terraform configuration sets up an EKS cluster on AWS using various modules.

# Provider configuration for AWS
provider "aws" {
  region     = var.region      # AWS region to use
  access_key = ""              # AWS access key (leave empty for security reasons)
  secret_key = ""              # AWS secret key (leave empty for security reasons)
}

# Local variables
locals {
  cluster_name = "education-eks-${random_string.suffix.result}" # Generates a unique cluster name using a random string
}

# Generate a random string to be used as a suffix
resource "random_string" "suffix" {
  length  = 8      # Length of the random string
  special = false  # Ensures the string is alphanumeric
}

# Create a VPC for the EKS cluster using multiple availability zones
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"  # Source of the VPC module
  version = "5.0.0"                          # Version of the VPC module

  name = "multi-az-vpc-eks"  # Name of the VPC
  cidr = "10.0.0.0/16"       # CIDR block for the VPC

  azs             = [format("%sa", var.region), format("%sb", var.region)] # Availability zones for high availability
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]                         # Private subnets
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]                         # Public subnets

  enable_nat_gateway = true  # Enable NAT Gateway
  enable_dns_hostnames = true  # Enable DNS hostnames

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared" # Tag for Kubernetes cluster
    "kubernetes.io/role/elb"                      = 1        # Tag for external load balancer
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"  # Tag for Kubernetes cluster
    "kubernetes.io/role/internal-elb"             = 1         # Tag for internal load balancer
  }
}

# EKS Cluster configuration
module "eks" {
  source  = "terraform-aws-modules/eks/aws"  # Source of the EKS module
  version = "19.15.3"                        # Version of the EKS module

  cluster_name    = local.cluster_name       # Name of the EKS cluster
  cluster_version = "1.27"                   # Kubernetes version

  vpc_id     = module.vpc.vpc_id             # VPC ID
  subnet_ids = module.vpc.private_subnets    # Subnet IDs

  cluster_endpoint_public_access = true  # Allows public access to the Kubernetes API server

  # Default configurations for node groups
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"  # Amazon Linux 2 AMI type for the nodes
  }

  # Configuration for managed node groups
  eks_managed_node_groups = {
    one = {
      name          = "node-group-1"  # Name of the first node group
      instance_types = ["t3.small"]   # Instance types for the nodes
      min_size      = 1               # Minimum size of the node group
      max_size      = 3               # Maximum size of the node group
      desired_size  = 2               # Desired size of the node group
    }

    two = {
      name          = "node-group-2"  # Name of the second node group
      instance_types = ["t3.small"]   # Instance types for the nodes
      min_size      = 1               # Minimum size of the node group
      max_size      = 2               # Maximum size of the node group
      desired_size  = 1               # Desired size of the node group
    }
  }
}

# Data source to retrieve the AWS IAM policy for the EBS CSI driver
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"  # ARN of the EBS CSI driver policy
}

# IAM role for the EBS CSI driver using OpenID Connect (OIDC)
module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"  # Source of the IAM module
  version = "4.7.0"                                                                # Version of the IAM module

  create_role                   = true                                          # Flag to create the role
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"  # Name of the IAM role
  provider_url                  = module.eks.oidc_provider                      # OIDC provider URL
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]      # ARN of the policy to attach to the role
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]  # Subjects for the OIDC role
}

# EBS CSI driver EKS add-on
resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name  # Name of the EKS cluster
  addon_name               = "aws-ebs-csi-driver"     # Name of the add-on
  addon_version            = "v1.20.0-eksbuild.1"     # Version of the add-on
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn  # IAM role ARN for the service account

  tags = {
    "eks_addon" = "ebs-csi"  # Tag for the add-on
    "terraform" = "true"     # Tag for Terraform
  }
}
