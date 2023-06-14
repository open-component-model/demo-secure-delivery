.PHONY: setup teardown

run:
	@./00-setup-demo/setup.sh --offline-mode 1

teardown:
	kind delete cluster --name aws-demo
