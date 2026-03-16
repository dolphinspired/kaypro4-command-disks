TOOLS    := tools

export PATH   := $(CURDIR)/$(TOOLS)/z88dk/bin:$(PATH)
export ZCCCFG := $(CURDIR)/$(TOOLS)/z88dk/lib/config

ZCC    := $(TOOLS)/z88dk/bin/zcc
RUNCPM := $(TOOLS)/runcpm/RunCPM
CPMCP  := $(TOOLS)/cpmtools/bin/cpmcp

SRCS := $(wildcard src/*.c)

# Generate an explicit rule per source file with the source as a real prerequisite.
# This is necessary because Make cannot uppercase the stem in a pattern rule target.
define compile_rule
build/$(shell echo $(notdir $(basename $(1))) | tr '[:lower:]' '[:upper:]').COM: $(1) | build
	$$(ZCC) +cpm -subtype=kaypro84 -create-app -Cl-L$$(TOOLS)/z88dk/libsrc -o $$@ $$<
	rm -f $$(patsubst %.COM,%.com,$$@) $$(patsubst %.COM,%.dsk,$$@)
endef

$(foreach src,$(SRCS),$(eval $(call compile_rule,$(src))))

TARGETS := $(foreach s,$(SRCS),build/$(shell basename $(s) .c | tr '[:lower:]' '[:upper:]').COM)

.PHONY: all setup test clean image

all: $(TARGETS)

setup:
	bash scripts/setup.sh

build:
	mkdir -p build

test: all
	bash test/run_tests.sh

image: all
	bash scripts/make_image.sh

clean:
	rm -rf build/
