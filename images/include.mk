### These variables should not be used in commands
dir := images/
output_dir := output/$(dir)
build_dir := build/$(dir)
###

linux_version := 3.13.1
packer_version := 1.9.0

# Ouput files
disk_img 	:= $(output_dir)linux4lego
vmlinuz 	:= $(output_dir)vmlinuz
ethfit_ko 	:= $(output_dir)lego-linux-modules/ethfit.ko
storage_ko 	:= $(output_dir)lego-linux-modules/storage.ko
pcomponent_bzimg := $(output_dir)lego-kernels/pcomponent.bzImage
mcomponent_bzimg := $(output_dir)lego-kernels/mcomponent.bzImage

# Targets
pcomponent_prerequisites := $(pcomponent_bzimg)
mcomponent_prerequisites := $(mcomponent_bzimg)
scomponent_prerequisites := $(disk_img) $(ethfit_ko) $(storage_ko) $(vmlinuz)

# Disk image
packer := $(build_dir)packer
seed_img :=  $(build_dir)seed.img
disk_img_name := $(notdir $(disk_img))
disk_input_tar := $(build_dir)$(disk_img_name)-input.tar
disk_input := $(build_dir)$(disk_img_name)-input

$(disk_img): $(build_dir)packer-output/$(disk_img_name)
	mkdir -p $(@D)
	cp $< $@

$(build_dir)packer-output/$(disk_img_name): cache_dir := $(build_dir)packer-cache/
$(build_dir)packer-output/$(disk_img_name): dir := $(dir)
$(build_dir)packer-output/$(disk_img_name): $(dir)disk/$(disk_img_name).pkr.hcl \
	$(dir)disk/install.sh $(packer) $(seed_img) $(qemu) $(disk_input_tar)
	rm -rf $(@D)
	export PATH=$(abspath $(qemu_dir)):$(abspath $(qemu_dir)build/):$$PATH && \
	PACKER_BUILD_DIR=$(cache_dir) $(abspath $(packer)) build \
		-var "cpus=$$(nproc)" \
		-var "out_dir=$(@D)" \
		-var "out_name=$(@F)" \
		-var "bios_dir=$(qemu_dir)pc-bios/" \
		-var "seedimg_path=$(seed_img)" \
		-var "input_tar=$(disk_input_tar)" \
		-var "install_script=$(dir)disk/install.sh" \
		$<

$(packer): $(build_dir)packer_$(packer_version)_linux_amd64.zip
	unzip -o -d $(@D) $<
	touch $@

$(build_dir)packer_$(packer_version)_linux_amd64.zip:
	mkdir -p $(@D)
	wget -O $@ https://releases.hashicorp.com/packer/$(packer_version)/packer_$(packer_version)_linux_amd64.zip

$(seed_img): $(dir)disk/user-data $(dir)disk/meta-data
	mkdir -p $(@D)
	rm -f $@
	cloud-localds $@ $^

$(disk_input_tar): $(disk_input)
	tar -cf $@ -C $< $(shell ls -A $<)

$(disk_input): dir := $(dir)
$(disk_input): $(vmlinuz) $(dir)disk/guestinit.sh
	mkdir -p $@
	cp $(dir)disk/guestinit.sh $@
	cp -r $(linux_src_dir) $@
	mv $@/$(shell basename $(linux_src_dir)) $@/linux


# Linux kernel

linux_src_dir := $(build_dir)linux-$(linux_version)/

.PHONY: build-linux
build-linux: $(vmlinuz)

$(vmlinuz): $(linux_src_dir)arch/x86/boot/bzImage
	mkdir -p $(@D)
	cp $< $@

$(linux_src_dir)arch/x86/boot/bzImage: $(dir)linux/config-$(linux_version) $(legoos_docker_ready) $(linux_src_dir) 
	mkdir -p $(linux_src_dir)
	cp $< $(linux_src_dir).config
	$(MAKE) start-container-legoos
	$(legoos_container_exec) "make -C$(container_root)$(linux_src_dir) -j$$(nproc)"
	$(MAKE) stop-docker-legoos

$(linux_src_dir): $(build_dir)linux-$(linux_version).tar.xz
	tar -xf $< -C $(shell dirname $@)

$(build_dir)linux-$(linux_version).tar.xz:
	mkdir -p $(@D)
	wget -O $@ https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-$(linux_version).tar.xz

# Processor and memory component
legoos_dir := $(dir)legoos/

# Ensure we are using the value for the current level of make
$(pcomponent_bzimg) $(mcomponent_bzimg): build_dir := $(build_dir)

$(pcomponent_bzimg): $(dir)legoos-configs/config-pcomponent $(legoos_docker_ready)
	mkdir -p $(@D)
	mkdir -p $(build_dir)pcomponent-build
	cp $< $(build_dir)pcomponent-build/.config
	$(MAKE) start-container-legoos
	$(legoos_container_exec) "make -C $(legoos_dir) mrproper && \
		make -C $(legoos_dir) O=$(container_root)$(build_dir)pcomponent-build -j$$(nproc)"
	$(MAKE) stop-docker-legoos
	cp $(build_dir)pcomponent-build/arch/x86/boot/bzImage $@

$(mcomponent_bzimg): $(dir)legoos-configs/config-mcomponent $(legoos_docker_ready)
	mkdir -p $(@D)
	mkdir -p $(build_dir)mcomponent-build
	cp $< $(build_dir)mcomponent-build/.config
	$(MAKE) start-container-legoos
	$(legoos_container_exec) "make -C $(legoos_dir) mrproper && \
		make -C $(legoos_dir) O=$(container_root)$(build_dir)mcomponent-build -j$$(nproc)"
	$(MAKE) stop-docker-legoos
	cp $(build_dir)mcomponent-build/arch/x86/boot/bzImage $@


# Linux kernel modules for the storage component
$(ethfit_ko): $(legoos_dir)linux-modules/fit/eth/ethfit.ko
	mkdir -p $(@D)
	cp $< $@

$(legoos_dir)linux-modules/fit/eth/ethfit.ko: $(vmlinuz)  
	$(MAKE) start-container-legoos
	$(legoos_container_exec) 'make KERNEL_PATH=$(container_root)$(linux_src_dir) -C $(@D)'
	$(MAKE) stop-docker-legoos

$(storage_ko): $(legoos_dir)linux-modules/storage/storage.ko
	mkdir -p $(@D)
	cp $< $@

$(legoos_dir)linux-modules/storage/storage.ko: $(vmlinuz)
	$(MAKE) start-container-legoos
	$(legoos_container_exec) 'make KERNEL_PATH=$(container_root)$(linux_src_dir) -C $(@D)'
	$(MAKE) stop-docker-legoos
