source qemu ws2022gui {
  iso_url          = "../iso/<WINDOWS_SERVER_2022_VL_ISO_NAME>"
  iso_checksum     = "sha256:74a1cd9c93c84ff891f1548323470e6d7fcd83f24a954633b3ae3014de7d0732"
  output_directory = "output/"

  accelerator  = "kvm"
  machine_type = "q35"
  use_default_display = true
  qemuargs = [
    ["-parallel", "none"],
    ["-m", "4096M"],
    ["-smp", "cpus=2"],
    ["-nic", "none"]
  ]

  cpus             = 2
  memory           = 4
  disk_size        = "30720M"
  disk_compression = true
  cd_files = [
    "../drivers/0.1.208/NetKVM/2k22/amd64/*",
    "../drivers/0.1.208/viostor/2k22/amd64/*",
    "../drivers/0.1.208/vioserial/2k22/amd64/*",
    "../scripts/*",
    "Autounattend.xml"
  ]

  communicator     = "none"
  shutdown_timeout = "300m"
}

build {
  sources = ["source.qemu.ws2022gui"]

  post-processors {
    post-processor manifest {
      output     = "manifest.json"
      strip_path = true
    }
  }
}
