DOCKER_NAME := simlego_simbricks_
DOCKER_EXEC := docker exec $(DOCKER_NAME) /bin/bash -c

.PHONY: stop-docker start-docker

stop-docker:
	docker rm -f $(DOCKER_NAME)

start-docker:
	docker run --rm -d -i --name $(DOCKER_NAME) \
		--mount type=bind,source=$(shell pwd),target=/workspace/LegoOS-sim \
		--workdir /workspace/LegoOS-sim \
		simbricks/simbricks-build
