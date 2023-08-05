#!/usr/bin/make -f

BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git log -1 --format='%H')

# don't override user values
ifeq (,$(VERSION))
  VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
  # if VERSION is empty, then populate it with branch's name and raw commit hash
  ifeq (,$(VERSION))
    VERSION := $(BRANCH)-$(COMMIT)
  endif
endif

NETWORK ?= Mainnet
ADDRESS_PREFIX ?= ki

PACKAGES_SIMTEST=$(shell go list ./... | grep '/simulation')
LEDGER_ENABLED ?= true
SDK_PACK := $(shell go list -m github.com/cosmos/cosmos-sdk | sed  's/ /\@/g')
TM_VERSION := $(shell go list -m github.com/tendermint/tendermint | sed 's:.* ::') # grab everything after the space in "github.com/tendermint/tendermint v0.34.7"
DOCKER := $(shell which docker)
BUILDDIR ?= $(CURDIR)/build

GO_MINOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f2)

export GO111MODULE = on

# process build tags

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

ifeq (cleveldb,$(findstring cleveldb,$(KID_BUILD_OPTIONS)))
  build_tags += gcc cleveldb
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace += $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

# process linker flags
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=kitools \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=kid \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(NETWORK)-$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)" \
		  -X github.com/tendermint/tendermint/version.TMCoreSemVer=$(TM_VERSION) \
		  -X github.com/KiFoundation/ki-tools/app/address.Bech32MainPrefix=$(ADDRESS_PREFIX)

ifeq (cleveldb,$(findstring cleveldb,$(KID_BUILD_OPTIONS)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
endif
ifeq (,$(findstring nostrip,$(KID_BUILD_OPTIONS)))
  ldflags += -w -s
endif
ifeq ($(LINK_STATICALLY),true)
  ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'
# check for nostrip option
ifeq (,$(findstring nostrip,$(KID_BUILD_OPTIONS)))
  BUILD_FLAGS += -trimpath
endif

#$(info $$BUILD_FLAGS is [$(BUILD_FLAGS)])

# The below include contains the tools target.
# include contrib/devtools/Makefile

###############################################################################
###                              Documentation                              ###
###############################################################################
check_version:
ifneq ($(GO_MINOR_VERSION),19)
	@echo "ERROR: Go version 1.19 is required for this version of Ki-tools."
	exit 1
endif

all: install lint test

BUILD_TARGETS := build install

build: BUILD_ARGS=-o $(BUILDDIR)/

$(BUILD_TARGETS): check_version go.sum $(BUILDDIR)/
	go $@ -mod=readonly $(BUILD_FLAGS) $(BUILD_ARGS) ./...

$(BUILDDIR)/:
	mkdir -p $(BUILDDIR)/

build-reproducible-all: build-reproducible-amd64 build-reproducible-arm64

build-reproducible-amd64:
	ARCH=x86_64 PLATFORM=linux/amd64 $(MAKE) build-reproducible-generic

build-reproducible-arm64:
	ARCH=aarch64 PLATFORM=linux/arm64 $(MAKE) build-reproducible-generic
	
build-reproducible-generic: go.sum
	$(DOCKER) rm $(subst /,-,latest-build-$(PLATFORM)) || true
	DOCKER_BUILDKIT=1 $(DOCKER) build -t latest-build-$(PLATFORM) \
		--build-arg ARCH=$(ARCH) \
		--build-arg PLATFORM=$(PLATFORM) \
		--build-arg BUILD_TARGET_PREFIX="$(BUILD_TARGET_PREFIX)" \
		--build-arg VERSION="$(VERSION)" \
		-f Dockerfile .
	$(DOCKER) create -ti --name $(subst /,-,latest-build-$(PLATFORM)) latest-build-$(PLATFORM) kid
	$(DOCKER) cp -a $(subst /,-,latest-build-$(PLATFORM)):/usr/local/bin/kid "$(CURDIR)/kid_$(shell echo '$(NETWORK)' | tr '[:upper:]' '[:lower:]')_$(subst /,_,$(PLATFORM))"
	sha256sum kid_$(shell echo '$(NETWORK)' | tr '[:upper:]' '[:lower:]')_$(subst /,_,$(PLATFORM)) >> ./kid_sha256.txt

build-linux: go.sum
	LEDGER_ENABLED=false GOOS=linux GOARCH=amd64 $(MAKE) build

build-contract-tests-hooks:
	mkdir -p $(BUILDDIR)
	go build -mod=readonly $(BUILD_FLAGS) -o $(BUILDDIR)/ ./cmd/contract_tests

go-mod-cache: go.sum
	@echo "--> Download go modules to local cache"
	@go mod download

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	@go mod verify

draw-deps:
	@# requires brew install graphviz or apt-get install graphviz
	go get github.com/RobotsAndPencils/goviz
	@goviz -i ./cmd/kid -d 2 | dot -Tpng -o dependency-graph.png

clean:
	rm -rf $(BUILDDIR)/ artifacts/

distclean: clean
	rm -rf vendor/

###############################################################################
###                                 Testnet                                 ###
###############################################################################

build-testnet-reproducible-all: build-testnet-reproducible-amd64 build-testnet-reproducible-arm64

build-testnet-reproducible-amd64:
	ARCH=x86_64 PLATFORM=linux/amd64 NETWORK=Testnet ADDRESS_PREFIX=tki BUILD_TARGET_PREFIX="-testnet" $(MAKE) build-reproducible-generic

build-testnet-reproducible-arm64:
	ARCH=aarch64 PLATFORM=linux/arm64 NETWORK=Testnet ADDRESS_PREFIX=tki BUILD_TARGET_PREFIX="-testnet" $(MAKE) build-reproducible-generic

build-testnet: go.sum
	NETWORK=Testnet ADDRESS_PREFIX=tki $(MAKE) build

###############################################################################
###                                 Devdoc                                  ###
###############################################################################

build-docs:
	@cd docs && \
	while read p; do \
		(git checkout $${p} && npm install && VUEPRESS_BASE="/$${p}/" npm run build) ; \
		mkdir -p ~/output/$${p} ; \
		cp -r .vuepress/dist/* ~/output/$${p}/ ; \
		cp ~/output/$${p}/index.html ~/output ; \
	done < versions ;
.PHONY: build-docs

sync-docs:
	cd ~/output && \
	echo "role_arn = ${DEPLOYMENT_ROLE_ARN}" >> /root/.aws/config ; \
	echo "CI job = ${CIRCLE_BUILD_URL}" >> version.html ; \
	aws s3 sync . s3://${WEBSITE_BUCKET} --profile terraform --delete ; \
	aws cloudfront create-invalidation --distribution-id ${CF_DISTRIBUTION_ID} --profile terraform --path "/*" ;
.PHONY: sync-docs


###############################################################################
###                           Tests & Simulation                            ###
###############################################################################

include sims.mk

test: test-unit test-build

test-all: check test-race test-cover

test-unit:
	@VERSION=$(VERSION) go test -mod=readonly -tags='ledger test_ledger_mock norace' ./...

test-race:
	@VERSION=$(VERSION) go test -mod=readonly -race -tags='ledger test_ledger_mock' ./...

test-cover:
	@go test -mod=readonly -timeout 30m -coverprofile=coverage.txt -covermode=atomic -tags='ledger test_ledger_mock' ./...

test-e2e:
	@VERSION=$(VERSION) go test -mod=readonly -timeout=25m -v ./tests/e2e

benchmark:
	@go test -mod=readonly -bench=. ./...

docker-build-debug:
	@docker build -t cosmos/kid-e2e --build-arg IMG_TAG=debug -f Dockerfile .

###############################################################################
###                                Linting                                  ###
###############################################################################

lint:
	golangci-lint run
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" | xargs gofmt -d -s

format:
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -path "./client/lcd/statik/statik.go" | xargs gofmt -w -s
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -path "./client/lcd/statik/statik.go" | xargs misspell -w
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -path "./client/lcd/statik/statik.go" | xargs goimports -w -local github.com/cosmos/cosmos-sdk


###############################################################################
###                                Localnet                                 ###
###############################################################################

.PHONY: all build-linux install format lint \
	go-mod-cache draw-deps clean build build-contract-tests-hooks \
	test test-all test-build test-cover test-unit test-race benchmark
