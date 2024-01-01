dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
output_dir := $(dir)output/
cache_dir := $(dir)cache/

PACKER_VERSION := 1.9.0
KERNEL_VERSION := 3.13.1

DISK_IMG := $(output_dir)ubuntu14

seedimg :=  $(cache_dir)seed.img
packer := $(cache_dir)packer_$(PACKER_VERSION)

$(output_dir):
	mkdir -p $@

$(seedimg): $(dir)user-data $(dir)meta-data
	mkdir -p $(dir $@)
	rm -f $@
	cloud-localds $@ $(dir)user-data $(dir)meta-data

$(packer):
	mkdir -p $(dir $@)
	wget -O $(cache_dir)packer_$(PACKER_VERSION)_linux_amd64.zip \
	    https://releases.hashicorp.com/packer/$(PACKER_VERSION)/packer_$(PACKER_VERSION)_linux_amd64.zip
	cd $(cache_dir) && unzip -u packer_$(PACKER_VERSION)_linux_amd64.zip
	mv $(cache_dir)packer $(packer)
	rm -f $(cache_dir)packer_$(PACKER_VERSION)_linux_amd64.zip

$(DISK_IMG): $(output_dir) $(packer) $(seedimg) $(SIMBRICKS_READY) $(QEMU) $(dir)ubuntu14.pkr.hcl
	rm -rf $(cache_dir)packer_output
	export PATH=$(SIMBRICKS_DIR)sims/external/qemu/:$(SIMBRICKS_DIR)sims/external/qemu/build/:$$PATH && \
	cd $(dir) && PACKER_CACHE_DIR=$(cache_dir)/packer_cache $(abspath $(packer)) build \
		-var "cpus=$$(nproc)" \
		-var "out_dir=$(cache_dir)packer_output/" \
		-var "out_name=$(notdir $(DISK_IMG))" \
		-var "bios_dir=$(SIMBRICKS_DIR)sims/external/qemu/pc-bios/" \
		-var "seedimg_path=$(seedimg)" \
		ubuntu14.pkr.hcl
	mv $(cache_dir)packer_output/$(notdir $(DISK_IMG)) $@

.PHONY: disk-image
disk-image: $(DISK_IMG)
