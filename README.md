# Cloud Init Module

This module creates a multi-part mime encoded cloud init userdata blob.

In other words, it can be used to configure EC2 (or other cloudinit enabled) machines.

It has two components- a "cloud-config" formatted file based off of the inputs to the module, and the ability to take in arbitrary "parts" that can be added as separate files. The cloud-config section should be good enough for pretty much everything though.

This module even automatically compresses the userdata if it gets too large, so that it's easily readable if small while still allowing larger files when needed.

## Usage

### Example

This first example enables two services, runs a bunch of commands, and adds two configuration files.

```terraform
module "cloudinit" {
  source  = "tedivm/cloudinit/general"
  version = "~> 1.0

  services = ["consul", "nomad"]

  runcmd = [
    "sed -i 's/After=network-online.target/After=opt.mount network-online.target consul.service/' /lib/systemd/system/nomad.service",
    "sed -i 's/After=network-online.target/After=opt.mount network-online.target/' /lib/systemd/system/consul.service",
    "mkdir -p /opt/consul",
    "chown consul:consul /opt/consul",
    "mkdir -p /opt/nomad",
    "chown nomad:nomad /opt/nomad"
  ]

  config_files = {
    "/etc/nomad.d/nomad.hcl" : templatefile("${path.module}/templates/nomad.hcl", local.template_vars),
    "/etc/consul.d/consul.hcl" : templatefile("${path.module}/templates/consul.hcl", local.template_vars),
  }
}

```


This version is a big more complex- it installs packages, enables and starts services, installs script files (with execution permissions), mounts an EBS volume with partition growth enabled, and then after everything else is done it runs a command to launch nomad jobs.

```terraform

locals {
  service_template_vars = {
    controller_count : var.controller_count,
    cluster_id : var.cluster_id,
    advertise_address : tolist(aws_network_interface.main.private_ips)[0]
  }

  service_files = {
    "/etc/nomad.d/nomad.hcl" : templatefile("${path.module}/templates/nomad.hcl", local.service_template_vars),
    "/etc/consul.d/consul.hcl" : templatefile("${path.module}/templates/consul.hcl", local.service_template_vars),
  }

  cron_files = {
    "/etc/cron.d/nomad_submit" : templatefile("${path.module}/templates/nomad_cron", { "config_bucket" : var.config_bucket })
  }

  script_files = {
    "/opt/nomad_core_jobs.sh" : templatefile("${path.module}/templates/nomad_core_jobs.sh",
      {
        "config_bucket" : var.config_bucket,
        "cluster_id" : var.cluster_id
      }
    ),
    "/opt/awscli_install.sh" : templatefile("${path.module}/templates/awscli_installer.sh", {}),
  }

}


module "cloudinit" {
  source  = "tedivm/cloudinit/general"
  version = "~> 1.0

  packages = ["unzip", "jq"]

  services = ["consul", "nomad"]

  script_files = local.script_files

  config_files = merge(local.service_files, local.cron_files)

  mounts = [
    ["/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.opt.id, "-", "")}", "/opt/data", "xfs", "defaults,x-systemd.makefs,x-systemd.required-by=consul.service,x-systemd.required-by=nomad.service", "0", "1"]
  ]

  grow_partition_devices = [
    "/opt/data"
  ]

  runcmd = [
    "systemctl start opt-data.mount",
    "/opt/awscli_install.sh",
    "mkdir -p /opt/jobspecs",
    "mkdir -p /opt/data/consul",
    "chown consul:consul /opt/data/consul",
    "mkdir -p /opt/data/nomad",
    "chown nomad:nomad /opt/data/nomad"
  ]

  endcmd = [
    "/opt/nomad_core_jobs.sh"
  ]

}
```

### Outputs

* `rendered` - The string containing the `user_data` to pass to the EC2 instances or Launch Templates.


## Resources Affected

This module only creates data- no resources are actually created by it.
