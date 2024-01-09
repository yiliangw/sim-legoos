.PHONY: all help

all: help

help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  run-hello-world:           run the hello world experiment"
	@echo "  run-phoenix-word-count:    run the phoenix word count experiment"
	@echo "  clean:                     clean all generated files"

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


# Experiments
experiment_dir := experiments/
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
	$(simbricks_run_cmd) $(abspath $(experiment_dir)hello-world.py)

phoenix_word_count := $(output_dir)phoenix/word_count

$(phoenix_word_count): $(legoos_docker_ready)
	$(MAKE) start-container-legoos
	$(legoos_container_exec) 'make -C $(experiment_dir)phoenix/phoenix-2.0/tests/word_count clean all'
	$(MAKE) stop-container-legoos
	mkdir -p $(@D)
	cp $(experiment_dir)phoenix/phoenix-2.0/tests/word_count/word_count $@

$(experiment_dir)phoenix/phoenix-2.0/tests/word_count/word_count:
	$(MAKE) start-container-simbricks
	$(simbricks_container_exec) 'make -C $(@D)'
	$(MAKE) stop-container-simbricks


.PHONY: run-phoenix-word-count
run-phoenix-word-count: $(simbricks_ready) $(qemu) $(phoenix_word_count) \
	$(pcomponent_prerequisites) $(mcomponent_prerequisites) $(scomponent_prerequisites)
	sudo \
	sync=1 sync_period=1000 \
	pcomponent_mac="52:54:00:12:34:56" \
	mcomponent_mac="52:54:00:12:34:57" \
	scomponent_mac="52:54:00:12:34:58" \
	$(simbricks_run_cmd) $(abspath $(experiment_dir)phoenix-word-count.py)


CLEAN_ALL := $(output_dir) $(build_dir)
.PHONY: clean
clean:
	sudo rm -rf $(CLEAN_ALL)
	$(MAKE) -C $(simbricks_dir) clean-all
	$(MAKE) -C $(experiment_dir)phoenix/phoenix-2.0/tests/word_count clean


include dev.mk

