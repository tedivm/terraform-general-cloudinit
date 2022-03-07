
terraform {
  experiments = [module_variable_optional_attrs]
}


#
# Commands
#

variable "bootcmd" {
  description = "Commands to be run right after boot. Commands here may not have network access."
  type        = list(any)
  default     = ["echo Starting boot commands."]
}

variable "runcmd" {
  description = "Commands to run once the user environment is initialized and packages have been installed, but before any custom services are started."
  type        = list(any)
  default     = ["echo Starting run commands."]
}

variable "endcmd" {
  description = "Commands run at the very end of the cloud-init sequence, after services have started. Useful for things like joining a cluster."
  type        = list(any)
  default     = ["echo Finished running commands."]
}


#
# Application
#


variable "services" {
  description = "A list of services which should be enabled and started. This does not install them, but it does run after `packages` are installed."
  type        = list(string)
  default     = []
}

variable "user_services" {
  description = "A list of maps of user services which should be enabled and started. Needs to include `user` and `name` for each service."
  type        = list(map(string))
  default     = []
}

variable "packages" {
  description = "A list of packages to be installed. These packages must exist in the systems software repository, or have a repository configured."
  type        = list(string)
  default     = ["nomad", "consul", "docker-ce", "docker-ce-cli", "containerd.io"]
}


#
# Files
#

variable "write_files" {
  description = "This is identical to the `write_files` cloud-config setting, and expects the same format. The `script_files` and `config_files` wrappers are a better choice for most files."
  default     = []
}

variable "config_files" {
  description = "A key/value object where the key is a file path and the value is the contents of the file. The file will not be executable, but is readable by the whole system."
  default     = {}
}

variable "script_files" {
  description = "A key/value object where the key is a file path and the value is the contents of the file. The file will be created with execution permissions."
  default     = {}
}


#
# Filesystem
#

variable "mounts" {
  description = "This is passed directly to the cloud-init `mounts` setting. It is extremely useful for adding EBS volumes."
  type        = list(list(any))
  default     = []
}

variable "grow_partition_devices" {
  description = "A list of devices that cloud-init should automatically grow. This is helpful if an EBS volume is expanded."
  type        = list(string)
  default     = []
}

#
# Any custom part can be added here.
#

variable "parts" {
  default = []
  type = list(object(
    {
      content      = string
      filename     = optional(string)
      content_type = optional(string)
      merge_type   = optional(string)
    }
  ))
}
