COMPONENT_NAME=ocm.software/demos/podinfo:v1.0.0
OUTPUT_DIR=.out
KEYNAME=gitopscon
TARGET_REGISTRY=ghcr.io/phoban01

.PHONY: clean
clean:
	@rm -rf ${OUTPUT_DIR}
	@rm -rf ${KEYNAME}.key ${KEYNAME}.key.pub


.PHONY: build
build: clean
	@ocm add componentversions --create --file ${OUTPUT_DIR} --scheme v3alpha1 componentfile.yaml

.PHONY: generate-keys
generate-keys:
	@ocm create rsakeypair ${KEYNAME}.key

.PHONY: sign
sign:
	@ocm sign component --signature ${KEYNAME} --private-key ${KEYNAME}.key ${OUTPUT_DIR}

.PHONY: push
push:
	@ocm transfer component -f ${OUTPUT_DIR} ${TARGET_REGISTRY}

.PHONY: verify
verify:
	@ocm verify component --signature ${KEYNAME} --public-key ${KEYNAME}.key.pub ${TARGET_REGISTRY}//${COMPONENT_NAME}
