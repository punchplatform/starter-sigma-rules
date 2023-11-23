include INFO
export

TARGET_DIR := $(CURDIR)/target
TMP_DIR := $(TARGET_DIR)/tmp
TMP_METADATA = $(TMP_DIR)/metadata.yml
TMP_DATA = $(TMP_DIR)/$(ARTIFACT_ID)-$(VERSION).zip
SRC_DIRS := $(CURDIR)/src/main
TARGET_ARTIFACT = $(TARGET_DIR)/$(ARTIFACT_ID)-$(VERSION)-artifact.zip
TARGET_METADATA := metadata/metadata.yml
SRCS := $(shell find $(SRC_DIRS) -type f)
TARGET_TEST := $(TARGET_DIR)/.tested
DOT:= .
DASH:= /
GROUP_PATH= $(subst $(DOT),$(DASH),$(GROUP_ID))

.PHONY: all
all: $(TARGET_ARTIFACT)

$(TARGET_TEST): $(SRCS)
	@docker run -v $(CURDIR):/workdir/ ghcr.io/punchplatform/puncher:$(PUNCH_VERSION) -T /workdir
	@mkdir -p $(TARGET_DIR)
	touch $(TARGET_TEST)

$(TMP_METADATA): $(METADATA) INFO
	@mkdir -p $(TMP_DIR)
	envsubst < $(TARGET_METADATA) > $(TMP_METADATA)

$(TMP_DATA): $(SRCS)
	@mkdir -p $(TMP_DIR)
	cd $(SRC_DIRS); zip -r $(TMP_DATA) *; cd -
	
$(TARGET_ARTIFACT): $(TARGET_TEST) $(TMP_METADATA) $(TMP_DATA)
	cd $(TMP_DIR); zip -r $(TARGET_ARTIFACT) *; cd -

.PHONY: package
package: $(TMP_METADATA) $(TMP_DATA) ## Package metadata and data into an artifact
	cd $(TMP_DIR); rm -f $(TARGET_ARTIFACT) ; zip -r $(TARGET_ARTIFACT) *; cd -

.PHONY: test
test: $(TARGET_TEST)## Recursively executes all unit and log files tests you included in your repository.
	docker run -v $(CURDIR):/workdir/ ghcr.io/punchplatform/puncher:$(PUNCH_VERSION) -T /workdir

.PHONY: clean ## Clean the repository
clean:
	rm -rf target

.PHONY: upload
upload:  package ## Upload the generated parser artifact to the default kooker artifact server. Check the INFO file.
	curl -XPOST "$(ARTIFACT_SERVER_URL)/v1/artifacts/upload" -F artifact="@$(TARGET_ARTIFACT)" -F override=true

.PHONY: interactive
interactive: ## Start the puncher image in interactive mode for you to check the content of the puncher image.
	docker run -it --entrypoint /bin/bash -v $(CURDIR):/workdir/ ghcr.io/punchplatform/puncher:$(PUNCH_VERSION)

.PHONY: local-install
local-install: clean package ## Install the artifact locally. This will require the 'usr/share/punch/artifacts' root folder be created already.
	mkdir -p ~/.m2/repository/${GROUP_PATH}/${ARTIFACT_ID}/${VERSION}
	cp $(TARGET_ARTIFACT) ~/.m2/repository/${GROUP_PATH}/${ARTIFACT_ID}/${VERSION}

.PHONY: version 
version: ## Get artifact version
	@echo $(VERSION)

.PHONY: name 
name: ## Get artifact name
	@echo $(ARTIFACT_ID)

.PHONY: help
help:
	@echo Punch Parser Artifact Makefile help
	@echo
	@echo Simply type in \'make\' to build the artifact. The additional helper rules described below 
	@echo are also available to simplify day to day development.  
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m\n"} /^[0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

