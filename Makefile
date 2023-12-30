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

.PHONY: build-simbricks
build-simbricks:
	$(DOCKER_EXEC) 'make -C simbricks -j$$(nproc) && \
		make -C simbricks -j$$(nproc) sims/external/qemu/ready'


