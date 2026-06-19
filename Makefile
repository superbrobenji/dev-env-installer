.PHONY: test lint test-unit test-docker

test: lint test-unit

lint:
	@find . -type f \( -name '*.sh' -o -name '*.bash' \) \
	  -not -path './tests/lib/*' -not -path './.git/*' \
	  -print0 | xargs -0 shellcheck -x

test-unit:
	@tests/lib/bats/bin/bats tests/unit/

test-docker:
	@bash tests/docker/run.sh
