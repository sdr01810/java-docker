docker_base_os           = ubuntu
docker_base_image        = ${docker_base_os}:16.04

docker_build_args_extra  = # --no-cache

docker_hub_user          = $(or ${DOCKER_HUB_USER},UNNOWN_DOCKER_HUB_USER)
#^-- override this on the make(1) command line or in the environment

container_name           = $(shell cat Docker.container.name)

image_tag                = ${docker_hub_user}/${container_name}

##

all :: build test

clean ::

build :: Dockerfile Makefile $(shell ls *.md *.sh *.txt)
	docker build ${docker_build_args_extra} --tag "${image_tag}" .

test :: build
	docker run "${image_tag}" ls -Alh

push ::
	@echo 1>&2
	@echo 1>&2 "NB: The Oracle Java license agreement restricts redistribution. Think twice..."
	@echo 1>&2
	docker push "${image_tag}"

##

Dockerfile : Dockerfile.in
	cat $< | perl -pe "s/[@]make:docker_base_image[@]/${docker_base_image}/" > $@

clean ::
	rm -f Dockerfile

##

