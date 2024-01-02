simbricks_docker := simbricks/simbricks-build
simbricks_docker_name := simlego_simbricks_
simbricks_docker_exec := docker exec $(simbricks_docker_name) /bin/bash -c

legoos_docker := legoos-build
legoos_docker_name := simlego_legoos_
legoos_docker_exec := docker exec $(legoos_docker_name) /bin/bash -c

legoos_docker_ready := legoos-docker.ready

.PHONY: start-docker-simbricks stop-docker-simbricks start-docker-legoos stop-docker-legoos

start-docker-simbricks:
	docker run --rm -d -i --name $(simbricks_docker_name) \
		--mount type=bind,source=$(shell pwd),target=/workspace/LegoOS-sim \
		--workdir /workspace/LegoOS-sim \
		simbricks/simbricks-build

stop-docker-simbricks:
	docker rm -f $(simbricks_docker_name)

start-docker-legoos:
	docker run --rm -d -i --name $(legoos_docker_name) \
		--mount type=bind,source=$(shell pwd),target=/workspace/LegoOS-sim \
		--workdir /workspace/LegoOS-sim \
		legoos-build

stop-docker-legoos:
	docker rm -f $(legoos_docker_name)

$(legoos_docker_ready): Dockerfile.legoos
	docker build -t $(legoos_docker) -f $< .
	touch $@
