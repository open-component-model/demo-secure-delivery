VERSION=v1.1.0
COMPONENT_NAME=ocm.software/demos/podinfo:${VERSION}
OUTPUT_DIR=.out
KEYNAME=ocm-signing
TARGET_REGISTRY=gitea.ocm.dev/software-provider

.PHONY: clean
clean:
	@rm -rf ${OUTPUT_DIR}
	@rm -rf ${KEYNAME}.key ${KEYNAME}.key.pub


.PHONY: build
build: clean
	@ocm add componentversions --create --file ${OUTPUT_DIR} --version ${VERSION} --scheme v3alpha1 componentfile.yaml

.PHONY: generate-keys
generate-keys:
	@ocm create rsakeypair ${KEYNAME}.key

.PHONY: sign
sign:
	@ocm sign component --lookup gitea.ocm.dev/software-provider --signature ${KEYNAME} --private-key ../00-setup-demo/signing-keys/${KEYNAME}.rsa.key ${OUTPUT_DIR}

.PHONY: push
push:
	@ocm transfer component -f ${OUTPUT_DIR} ${TARGET_REGISTRY}

.PHONY: verify
verify:
	@ocm verify component --signature ${KEYNAME} --public-key ../00-setup-demo/signing-keys/${KEYNAME}.rsa.pub ${TARGET_REGISTRY}//${COMPONENT_NAME}

.PHONY: run
run:
	./script.sh

