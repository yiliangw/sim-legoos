### These variables should not be used in commands
dir := $(dir $(lastword $(MAKEFILE_LIST)))
output_dir := output/
build_dir := build/$(dir)
###

linux_version := 3.13.1
packer_version := 1.9.0

# Ouput files
disk_img 	:= $(output_dir)ubuntu-14
vmlinux 	:= $(output_dir)vmlinux-$(linux_version)
ethfit_ko 	:= $(output_dir)ethfit.ko
storage_ko 	:= $(output_dir)storage.ko


# Disk image
packer := $(build_dir)packer_$(packer_version)
seed_img :=  $(build_dir)seed.img
disk_img_name := $(notdir $(disk_img))

.PHONY: build-disk-image
build-disk-image: $(disk_img)

$(disk_img): $(build_dir)packer_output/$(disk_img_name)
	mkdir -p $(@D)
	cp $< $@

$(build_dir)packer_output/$(disk_img_name): cache_dir := $(build_dir)packer_cache/
$(build_dir)packer_output/$(disk_img_name): $(dir)disk/ubuntu-14.pkr.hcl $(packer) $(seed_img) $(qemu_ready)
	rm -rf $(@D)
	export PATH=$(abspath $(qemu_dir)):$(abspath $(qemu_dir)build/):$$PATH && \
	PACKER_BUILD_DIR=$(cache_dir) $(abspath $(packer)) build \
		-var "cpus=$$(nproc)" \
		-var "out_dir=$(@D)" \
		-var "out_name=$(@F)" \
		-var "bios_dir=$(qemu_dir)pc-bios/" \
		-var "seedimg_path=$(seed_img)" \
		$<

$(packer): $(build_dir)packer_$(packer_version)_linux_amd64.zip
	unzip -u -d$(@D) $<
	mv $(@D)/packer $(packer)

$(build_dir)packer_$(packer_version)_linux_amd64.zip:
	mkdir -p $(@D)
	wget -O $@ https://releases.hashicorp.com/packer/$(packer_version)/packer_$(packer_version)_linux_amd64.zip

$(seed_img): $(dir)disk/user-data $(dir)disk/meta-data
	mkdir -p $(@D)
	rm -f $@
	cloud-localds $@ $^


# Linux kernel

linux_src_dir := $(build_dir)linux-$(linux_version)/

.PHONY: build-linux
build-linux: $(vmlinux)

$(vmlinux): $(linux_src_dir)arch/x86/boot/bzImage
	mkdir -p $(@D)
	cp $(linux_src_dir)arch/x86/boot/bzImage $@

$(linux_src_dir)arch/x86/boot/bzImage: $(dir)linux/config-$(linux_version) $(legoos_docker_ready) $(linux_src_dir) 
	cp $< $(linux_src_dir).config
	$(MAKE) start-container-legoos
	$(legoos_container_exec) "make -C$(linux_src_dir) -j$$(nproc)"
	$(MAKE) stop-docker-legoos

$(linux_src_dir): $(build_dir)/linux-$(linux_version).tar.xz
	tar -xf $< -C $(shell dirname $@)

$(build_dir)/linux-$(linux_version).tar.xz:
	mkdir -p $(@D)
	wget -O $@ https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-$(linux_version).tar.xz


# Linux kernel modules for the storage component
legoos_dir := $(dir)legoos/

.PHONY: build-linux-modules
build-linux-modules: $(ethfit_ko) $(storage_ko)

$(ethfit_ko): $(legoos_dir)linux-modules/fit/eth/ethfit.ko
	mkdir -p $(@D)
	cp $< $@

$(legoos_dir)linux-modules/fit/eth/ethfit.ko: $(vmlinux)  
	$(MAKE) start-container-legoos
	$(legoos_container_exec) 'make KERNEL_PATH=$(container_root)$(linux_src_dir) -C $(@D)'
	$(MAKE) stop-docker-legoos

$(storage_ko): $(legoos_dir)linux-modules/storage/storage.ko
	mkdir -p $(@D)
	cp $< $@

$(legoos_dir)linux-modules/storage/storage.ko: $(vmlinux)
	$(MAKE) start-container-legoos
	$(legoos_container_exec) 'make KERNEL_PATH=$(container_root)$(linux_src_dir) -C $(@D)'
	$(MAKE) stop-docker-legoos
