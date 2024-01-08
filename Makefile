.PHONY: all help

all: help

help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  start-docker:      start container simbricks/simbricks-build"
	@echo "  stop-docker:       stop and remove container simbricks/simbricks-build"
	@echo "  build-simbricks:   build required components in simbricks"
	@echo "  help:              print this help message"

include docker.mk
include images/include.mk

output_dir := output/
build_dir := build/

simbricks_dir := simbricks/
qemu_dir := $(simbricks_dir)sims/external/qemu/
qemu := $(qemu_dir)build/qemu-system-x86_64

simbricks_ready := $(build_dir)simbricks.ready

$(simbricks_ready): $(simbricks_dir)
	$(MAKE) start-container-simbricks
	$(simbricks_container_exec) 'make -C $(simbricks_dir) -j$$(nproc)'
	$(MAKE) stop-container-simbricks
	mkdir -p $(@D) && touch $@

$(qemu): $(qemu_dir)
	$(MAKE) start-container-simbricks
	$(simbricks_container_exec) 'make -C $(simbricks_dir) -j$$(nproc) sims/external/qemu/ready'
	$(MAKE) stop-container-simbricks

simbricks_run_cmd := python3 $(simbricks_dir)experiments/run.py --force --verbose \
	--repo=$(simbricks_dir) --workdir=$(output_dir) --outdir=$(output_dir) --cpdir=$(output_dir) \
	--runs=0 \

.PHONY: run-hello-world
run-hello-world: $(simbricks_ready) $(qemu) $(pcomponent_prerequisites) $(mcomponent_prerequisites) $(scomponent_prerequisites)
	sudo \
	sync=1 sync_period=2000 \
	pcomponent_mac="52:54:00:12:34:56" \
	mcomponent_mac="52:54:00:12:34:57" \
	scomponent_mac="52:54:00:12:34:58" \
	$(simbricks_run_cmd) $(abspath experiments/hello-world.py)


CLEAN_ALL := $(output_dir) $(build_dir)
.PHONY: clean
clean:
	sudo rm -rf $(CLEAN_ALL)


include dev.mk

