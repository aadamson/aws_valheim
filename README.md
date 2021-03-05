# aws_valheim

Ansible plays for deploying and managing a
[Valheim](https://www.valheimgame.com/) server on Amazon Web Services.

## Acknowledgements

The server is powered by the [brilliant scripts](https://github.com/Nimdy/Dedicated_Valheim_Server_Script)
developed by Nimdy/ZeroBandwidth. As an alternative to this guide, check out
their guide (linked above) and use their DigitalOcean referral code.

## Getting Started

### Create a virtual environment

We need a Python environment with ansible, boto, etc. installed.

Note that we have pinned ansible to 2.9.9. Everything likely works with anisble,
2.10, but I haven't tried it.

```bash
# From the root of this project
python3 -m venv env  # create a virtualenv in env/
source env/bin/activate  # activate the virtualenv
pip install -r requirements.txt
```

### Copy `secrets.yaml.example` to `secrets.yaml`

```bash
cp ansible/ansible/config/secrets.yaml.example ansible/ansible/secrets.yaml
```

### Create an IAM role for ansible usage

We need credentials for the AWS API. To obtain them log in to your AWS console
and follow the [instructions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html#id_users_create_console).
Choose a programmatic access option and apply the `AdministratorAccess` policy
to give administrative access to your API (or some more narrow set of privileges
if you're being properly circumspect). 

Put your newly created IAM credentials in a file that we will source later 
(e.g. `valheim_aws_rc`):
```bash
echo "export AWS_ACCESS_KEY_ID=<your key_id>" >> ~/valheim_aws_rc
echo "export AWS_SECRET_ACCESS_KEY=<your secret key>" >> ~/valheim_aws_rc
source ~/valheim_aws_rc
```

Create a copy of `ansible/src/aws/credentials.example` called `credentials`
and fill in your access key ID and secret access key:
```bash
cp ansible/src/aws/credentials.example ansible/src/aws/credentials
vim ansible/src/aws/credentials  # fill it in
```

### Create a key pair and download it 

Go to the [*Key Pairs*](https://us-east-2.console.aws.amazon.com/ec2/v2/home?region=us-east-2#KeyPairs:)
section on the EC2 dashboard and click "Create Key Pair". Select *"pem"* as the
file format. Download the .pem file when prompted and place it somewhere you'll
remember.

In `secrets.yaml`, 
- edit the value of `aws_key_location` to the location you just
  downloaded the .pem file to (either an absolute path or relative to
  `secrets.yaml`).
- edit the value of `aws_ssh_key` to contain the name of the key pair.

### Add the key pair to your ssh-agent

This is necessary so that ansible can connect to the server that we will be
creating.
```bash
ssh-add <path to .pem file>
```

### Create an Elastic IP

We'll assign an Elastic IP to our server so that we can easily terminate and
recreate it without having to change the IP players connect to.

In the EC2 dashboard, go to the
[*Elastic IPs*](https://us-east-2.console.aws.amazon.com/ec2/v2/home?region=us-east-2#Addresses:) 
section. Click *Allocate Elastic IP address*. Add a tag to the EIP with the
key `valheim` (you don't need to set a value).

### Record your VPC ID

Go to the [*Your VPCs*](https://us-east-2.console.aws.amazon.com/vpc/home?region=us-east-2#vpcs:)
section of your VPC dashboard. Either create a dedicated VPC for your server,
or use an existing one. Note the `VPC ID `. Open `secrets.yaml` and set the
`vpc_id` value.

### Set the bucket name for your backups

The server will automatically backup your world (and restart the Valheim
server) at 0 and 12 UTC every day. The backups will be stored in an S3 bucket.
You need to choose a name for the S3 bucket that is unique across all S3
buckets. Go to `secrets.yaml` and set the `bucket` value to something unique
(e.g. `valheim_backups` followed by a random string).

### Configure your Valheim server

Fill out values for `display_name`, `world_name`, `user_password`, and
`password` under `server`. Should be reasonably self-explanatory. Don't use
special characters.

### (Optional) Set the initial world

#### From a local save

If you want your server to use an existing world, you need to create a tar.gz
archive containing the `.db` and `.fwl` files for it. On Windows, the default
world save location is
`C:\Users\(Your PC Username)\AppData\LocalLow\IronGate\Valheim\worlds`. There
will be file pairs like `world1.db` and `world1.fwl` in it. For the world you
want to resume, copy the pair to a directory. Then, create a tarball containing
just these two files and put the resulting tarball in its own directory (e.g.
`world1-backups`):

```bash
mkdir world1-backups
tar -czf world1-backups/world1-backup.tar.gz -C <directory containing world1.{db, fwl}> . 
```

In `secrets.yaml`, set `initial_world_local_path` to the absolute path of the
directory containing the tarball (in the above example, `world1-backups`).

#### From a backup on S3

If you have previously run a server using this guide, there should be backups
in the bucket you created above in a subdirectory named after `world_name`
(so, e.g., `s3:/valheim_backups-d34db33f/world1/`). In that case, set
`initial_world_s3_path` to e.g. `world1` or whatever the name of the subdirectory
is that contains the backup tarballs. The most recent tarball will be restored.

### Launch the server

You should now be ready to launch the server.

```bash
ansible-playbook setup-play.yaml
```

That's it! If everything went well, you should now have a working server that
you can connect to on port 2456 at the Elastic IP you created above. If not,
please create an issue.

## Managing the server

### Connecting to it

```bash
ssh -F ansible/ansible/ssh_config worker0
```

### Tearing it down

```bash
ansible-playbook -i aws_ec2.yaml cleanup-play.yaml
```

### Manual backup

Note that as with the automated backups, this will restart the Valheim
server.

```bash
ansible-playbook -i aws_ec2.yaml backup-play.yaml
```
