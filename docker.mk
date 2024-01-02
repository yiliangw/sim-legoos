simbricks_docker_img := simbricks/simbricks-build
simbricks_container_name := simlego_simbricks_
simbricks_container_exec := docker exec $(simbricks_container_name) /bin/bash -c

legoos_docker_img := legoos-build
legoos_container_name := simlego_legoos_
legoos_container_exec := docker exec $(legoos_container_name) /bin/bash -c

legoos_docker_ready := $(build_dir)legoos-docker.ready

define start_container # $(1) - container name, $(2) - image name
	$(call stop_container,$(1))
	docker run --rm -d -i --name $(1) \
		--mount type=bind,source=$(shell pwd),target=/workspace/ \
		--workdir /workspace/ \
		$(2)
endef

define stop_container
	@if docker ps -q -f name="^$(1)$$"; then \
		echo "Stopping container $(1)"; \
		docker rm -f $(1); \
	else \
		echo "Container $(1) not running"; \
	fi
endef

.PHONY: start-container-simbricks stop-container-simbricks start-container-legoos stop-docker-legoos

start-container-simbricks:
	$(call start_container,$(simbricks_container_name),$(simbricks_docker_img))

stop-container-simbricks:
	$(call stop_container,$(simbricks_container_name))

start-container-legoos:
	$(call start_container,$(legoos_container_name),$(legoos_docker_img))

stop-container-legoos:
	$(call stop_container,$(legoos_container_name))

$(legoos_docker_ready): Dockerfile.legoos
	docker build -t $(legoos_docker_img) -f $< .
	touch $@
