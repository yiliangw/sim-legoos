.PHONY: build-pcomponent
build-pcomponent:
	rm -f $(pcomponent_bzimg)
	$(MAKE) $(pcomponent_bzimg)

.PHONY: build-mcomponent
build-mcomponent:
	rm -f $(mcomponent_bzimg)
	$(MAKE) $(mcomponent_bzimg)

.PHONY: build-storage-modules
build-storage-modules:
	rm -f $(ethfit_ko) $(storage_ko)
	$(MAKE) $(ethfit_ko) $(storage_ko)

.PHONY: run-pcomponent
run-pcomponent: $(simbricks_ready) $(qemu) $(pcomponent_prerequisites)
	$(MAKE) build-pcomponent
	sudo $(qemu) -machine q35,accel=kvm:tcg -serial mon:stdio \
		-cpu Skylake-Server -display none -nic none \
		-m 8G -smp 8 \
		-kernel $(pcomponent_bzimg) \
		-append "earlyprintk=serial,ttyS0,115200 console=ttyS0 memmap=2G\$$4G initcmd=\"hihihi arg1  arg2 \"" \
		-L $(qemu_dir)pc-bios

.PHONY: run-mcomponent
run-mcomponent: $(simbricks_ready) $(qemu) $(mcomponent_prerequisites)
	$(MAKE) build-mcomponent
	sudo $(qemu) -machine q35,accel=kvm:tcg -serial mon:stdio \
		-cpu Skylake-Server -display none -nic none \
		-m 8G -smp 8 \
		-kernel $(mcomponent_bzimg) \
		-append "earlyprintk=serial,ttyS0,115200 console=ttyS0" \
		-L $(qemu_dir)pc-bios

.PHONY: build-disk-image
build-disk-image:
	rm -f $(disk_img)
	$(MAKE) $(disk_img)


qemu := $(qemu_dir)build/qemu-system-x86_64

.PHONY: run-disk-image
run-disk-image: $(qemu) $(disk_img) $(vmlinuz)
	sudo $(qemu) -machine q35,accel=kvm:tcg -serial mon:stdio \
		-cpu Skylake-Server -display none -nic none \
		-m 8G -smp 8 \
		-drive file=$(disk_img),if=ide,index=0,media=disk \
		-drive file=output/LegoOS-hello-world/0/cfg.scomponent.tar,if=ide,index=1,media=disk,format=raw \
		-L $(qemu_dir)pc-bios
	

.PHONY: run-phoenix-local
run-phoenix-local:
	rm -f $(phoenix_word_count)
	$(MAKE) $(phoenix_word_count)
	$(phoenix_word_count) $(experiment_dir)phoenix/words.txt

