.PHONY: setup teardown

run:
	@./00-setup-demo/setup.sh --offline-mode 1

teardown:
	kind delete cluster --name ocm-demo
	rm -r 00-setup-demo/charts/telepresence/
