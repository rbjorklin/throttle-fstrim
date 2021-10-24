BINARY = throttle_fstrim
PROFILE ?= dev
DOCKER = $(shell bash -c 'basename $$(which podman 2> /dev/null) 2> /dev/null || echo docker')
SELINUX = $(shell bash -c '( [ "$$(getenforce)" = "Enforcing" ] && echo -n ":z") || echo -n ""')

.PHONY: deps build image

image:
	$(DOCKER) build --file Dockerfile --tag throttle-fstrim-build:latest .

deps:
	opam install --yes --deps-only .

build:
	opam exec -- dune build --profile $(PROFILE) @install

clean:
	rm -rf _build

docker-%: image
	$(DOCKER) run --rm -ti --volume $(PWD):/build$(SELINUX) --workdir /build throttle-fstrim-build make $* PROFILE=$(PROFILE)
