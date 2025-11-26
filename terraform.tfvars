region = "eu-west-2"
# optional: override availability_zones = ["us-east-1a","us-east-1b"]
key_pair_name = "kp"
# put your real public ip in CIDR format:
my_ip = "81.110.254.210/32"

# if you want Terraform to create a keypair from a local public key, set:
# create_key_pair = true
# public_key_path = "~/.ssh/id_rsa.pub"
