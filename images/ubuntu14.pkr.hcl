
variable "cpus" {
  type    = string
  default = "4"
}

variable "memory" {
  type    = string
  default = "4096"
}

variable "out_dir" {
  type    = string
  default = ""
}

variable "out_name" {
  type    = string
  default = "ubuntu-14"
}

variable "bios_dir" {
  type    = string
  default = ""
}

variable "seedimg_path" {
  type    = string
  default = ""
}


source "qemu" "ubuntu14" {
  output_directory = "${var.out_dir}"
  communicator     = "ssh"
  cpus             = "${var.cpus}"
  memory           = "${var.memory}"
  format           = "qcow2"
  disk_image       = true
  disk_compression = false
  headless         = true
  iso_url          = "https://cloud-images.ubuntu.com/releases/trusty/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img"
  iso_checksum     = "file:https://cloud-images.ubuntu.com/releases/trusty/release/SHA256SUMS"
  net_device       = "virtio-net"
  qemuargs         = [
    ["-machine", "pc-q35-4.2,accel=kvm:tcg,usb=off,vmport=off,dump-guest-core=off"],
    ["-drive", "file=${var.out_dir}/${var.out_name},if=ide,index=0,cache=writeback,discard=ignore,media=disk,format=qcow2"],
    ["-drive", "file=${var.seedimg_path},if=ide,index=1,media=disk,driver=raw"],
    ["-L", "${var.bios_dir}"],
    ["-boot", "c"]
  ]
  shutdown_command = "sudo shutdown -P now"
  ssh_password     = "ubuntu"
  ssh_username     = "ubuntu"
  ssh_timeout      = "5m"
  vm_name          = "${var.out_name}"
}

build {
  sources = ["source.qemu.ubuntu14"]

  provisioner "shell" {
    inline = ["pwd"]
  }
}
