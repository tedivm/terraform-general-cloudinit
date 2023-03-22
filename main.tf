
locals {

  # These files all get executable permissions.
  script_files = [for key, value in var.script_files : {
    "path" : key,
    "content" : value,
    "permissions" : "0755"
  }]

  # These files are just text/data.
  config_files = concat(
    [for file_path, contents in var.config_files :
      {
        "path" : file_path,
        "content" : contents
      }
    ],
  )

  # Create run commands from base config, service starts, and module input
  runcmd = concat(
    ["systemctl daemon-reload"],
    var.runcmd,
    flatten([for service in var.services : [
      "systemctl enable ${service}",
      "systemctl start --no-block ${service}",
    ]]),
    flatten([for service in var.user_services : [
      "su - ${service.user} -c 'systemctl --user enable ${service.name}'",
      "su - ${service.user} -c 'systemctl --user start --no-block ${service.name}'",
    ]]),
    var.endcmd
  )

  cloud_config = yamlencode(
    # Build custom config from input and local variables
    {
      "write_files" : concat(local.script_files, local.config_files, var.write_files),
      "runcmd" : local.runcmd,
      "bootcmd" : var.bootcmd,
      "mounts" : var.mounts,
      "packages" : var.packages,
      "growpart" : {
        "mode" : "auto",
        "devices" : concat(["/"], var.grow_partition_devices)
      },
    }
  )
}

data "cloudinit_config" "main" {
  base64_encode = true

  # Automatically GZIP if things get too big (with reasonable margin for error).
  # Cloud Init Length + Initial MIME Headers + Estimated "Parts" Length + Estimated "parts" headers > 85% of the total space
  gzip = length(local.cloud_config) + 180 + length(yamlencode(var.parts)) + (length(var.parts) * 100) > (16384 * 0.85)

  ## Module Generated Configs using "cloud-config" format.
  part {
    content      = local.cloud_config
    content_type = "text/cloud-config"
  }


  # Caller Specific Configs
  dynamic "part" {
    for_each = var.parts
    content {
      content      = parts.value["content"]
      filename     = try(parts.value["filename"], null)
      content_type = try(parts.value["content_type"], null)
      merge_type   = try(parts.value["merge_type"], null)
    }
  }
}
