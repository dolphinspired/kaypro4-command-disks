TOOLS := tools

export PATH   := $(CURDIR)/$(TOOLS)/z88dk/bin:$(PATH)
export ZCCCFG := $(CURDIR)/$(TOOLS)/z88dk/lib/config

.PHONY: all setup test clean image

all:
	SRC_DIR=src bash scripts/compile.sh

setup:
	bash scripts/setup.sh

test: all
	bash test/run_tests.sh

image: all
	bash scripts/make_image.sh

clean:
	rm -rf build/
