source qemu ws2019core {
  iso_url          = "../iso/<WINDOWS_SERVER_2019_VL_ISO_NAME>"
  iso_checksum     = "sha256:47ec5da25b232b2e7a1c10f3ee22b0f0e68eb1ea4d338e9d1d8f9db30a8f789e" 
  output_directory = "output/"

  accelerator  = "hvf"
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
  disk_size        = "20480M"
  disk_compression = true
  cd_files = [
    "../drivers/0.1.208/netkvm/2k19/amd64/*",
    "../drivers/0.1.208/viostor/2k19/amd64/*",
    "../drivers/0.1.208/vioserial/2k19/amd64/*",
    "../scripts/*",
    "Autounattend.xml"
  ]

  communicator     = "none"
  shutdown_timeout = "300m"
}

build {
  sources = ["source.qemu.ws2019core"]

  post-processors {
    post-processor manifest {
      output     = "manifest.json"
      strip_path = true
    }
  }
}
