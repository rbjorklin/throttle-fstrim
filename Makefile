BINARY = throttle_fstrim
PROFILE ?= release

.PHONY: install build run gen-opam

install:
	opam install --yes --deps-only .

gen-opam:
	dune build @install

build:
	opam exec -- dune build --profile $(PROFILE)

run: build
	./_build/default/src/bin/$(BINARY).exe

test: build
	docker build -t throttle-fstrim-test .
	docker run --security-opt label=disable --cap-add SYS_ADMIN --detach --volume $(CURDIR)/workdir:/workdir --name sysbench throttle-fstrim-test:latest sleep 600
	docker exec -t sysbench sysbench fileio prepare
	docker exec -t sysbench sysbench fileio run --file-test-mode=rndrw
	docker rm -f sysbench

clean:
	docker rm -f sysbench
