### These variables should not be used in commands
dir := $(dir $(lastword $(MAKEFILE_LIST)))
output_dir := output/
build_dir := build/$(dir)
###

packer_version := 1.9.0
linux_version := 3.13.1

disk_img := $(output_dir)ubuntu-14
vmlinux := $(output_dir)vmlinux-$(linux_version)

linux_src_dir := $(build_dir)linux-$(linux_version)/
seed_img :=  $(build_dir)seed.img
packer := $(build_dir)packer_$(packer_version)


$(seed_img): $(dir)disk/user-data $(dir)disk/meta-data
	mkdir -p $(@D)
	rm -f $@
	cloud-localds $@ $^

$(build_dir)packer_$(packer_version)_linux_amd64.zip:
	mkdir -p $(@D)
	wget -O $@ https://releases.hashicorp.com/packer/$(packer_version)/packer_$(packer_version)_linux_amd64.zip

$(packer): $(build_dir)packer_$(packer_version)_linux_amd64.zip
	unzip -u -d$(@D) $<
	mv $(@D)/packer $(packer)

$(build_dir)packer_output/$(notdir $(disk_img)): cache_dir := $(build_dir)packer_cache/
$(build_dir)packer_output/$(notdir $(disk_img)): $(dir)disk/ubuntu-14.pkr.hcl $(packer) $(seed_img) $(qemu_ready)
	rm -rf $(@D)
	export PATH=$(abspath $(qemu_dir)):$(abspath $(qemu_dir)build/):$$PATH && \
	PACKER_BUILD_DIR=$(cache_dir) $(abspath $(packer)) build \
		-var "cpus=$$(nproc)" \
		-var "out_dir=$(@D)" \
		-var "out_name=$(@F)" \
		-var "bios_dir=$(qemu_dir)pc-bios/" \
		-var "seedimg_path=$(seed_img)" \
		$<
	
$(disk_img): $(build_dir)packer_output/$(notdir $(disk_img))
	mkdir -p $(@D)
	cp $< $@

.PHONY: build-disk-image
build-disk-image: $(disk_img)

$(build_dir)/linux-$(linux_version).tar.xz:
	mkdir -p $(@D)
	wget -O $@ https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-$(linux_version).tar.xz

$(linux_src_dir): $(build_dir)/linux-$(linux_version).tar.xz
	tar -xf $< -C $(shell dirname $@)

$(vmlinux): $(dir)linux/config-$(linux_version) $(legoos_docker_ready) $(linux_src_dir) 
	mkdir -p $(@D)
	cp $< $(linux_src_dir).config
	$(MAKE) start-container-legoos
	$(legoos_container_exec) "make -C$(linux_src_dir) -j$$(nproc) bzImage"
	$(MAKE) stop-docker-legoos
	cp $(linux_src_dir)arch/x86/boot/bzImage $@

.PHONY: build-linux
build-linux: $(vmlinux)

