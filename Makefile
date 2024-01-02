.PHONY: all
all: help

.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  start-docker:      start container simbricks/simbricks-build"
	@echo "  stop-docker:       stop and remove container simbricks/simbricks-build"
	@echo "  build-simbricks:   build required components in simbricks"
	@echo "  help:              print this help message"


include docker.mk
include images/include.mk

SIMBRICKS_DIR := $(abspath simbricks)/
SIMBRICKS_READY := simbricks.ready
QEMU_IMG := $(SIMBRICKS_DIR)sims/external/qemu/build/qemu-img
QEMU := $(SIMBRICKS_DIR)sims/external/qemu/build/qemu-system-x86_64

.PHONY: build-simbricks
build-simbricks: $(SIMBRICKS_READY)

$(SIMBRICKS_READY): simbricks/
	$(simbricks_docker_exec) 'make -C simbricks -j$$(nproc) && \
		make -C simbricks -j$$(nproc) sims/external/qemu/ready'
	touch $@
