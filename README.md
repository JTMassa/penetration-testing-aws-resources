# Temporary Terraform penetration testing environment

This project provisions a separately managed Linux EC2 environment for an approved vendor engagement.

It provides:

- An EC2 instance in the specified approved VPC and subnet.
- SSM access by default, with optional SSH restricted to explicitly supplied CIDRs.
- Individual tester accounts and optional approved SSH public keys.
- An encrypted root volume and encrypted gp3 tools/output volume.
- An instance profile containing SSM access plus only the CloudWatch log permissions used by the host agent.
- CloudWatch host logs and an encrypted, private CloudTrail audit bucket.
- Project, owner, purpose, expiration, and management tags on resources.

## Use


1. Confirm the AMI, subnet route/NAT requirements, tester identities, and approved access source addresses.
2. Run:

```text
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

3. Record the outputs and provide access only through the approved process.
4. Preserve required evidence, remove tester access, and run `terraform destroy` when the engagement is complete.

The AWS account must already permit the Terraform operator to create the listed resources. The selected subnet must provide the network access required by SSM and approved package repositories.

It's been Julius T. Massa with AI assistance.