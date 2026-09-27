.PHONY: lint test check resources

lint:
	luacheck .

# tests/run.lua runs every tests/*_test.lua; pass FILE=jobs_test for one.
test:
	luajit tests/run.lua $(FILE)

check: lint test

# Regenerate tests/data/*.lua from a CatsEyeXI checkout: make resources CATSEYE=../catseyexi
resources:
	luajit tools/gen_resources.lua $(CATSEYE) $(shell git -C $(CATSEYE) rev-parse --short=12 HEAD)
