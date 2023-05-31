# Applications

### Weave Gitops Dashboard: [https://weave-gitops.ocm.dev](https://weave-gitops.ocm.dev/kustomization/details?clusterName=Default&name=podinfo-component&namespace=flux-system)

### Podinfo Homepage: [https://podinfo.ocm.dev](https://podinfo.ocm.dev)

---

This repository contains applications deployed using OCM & Flux. This setup simulates an air-gapped scenario whereby software is deployed in a segregated network without direct internet access.

Instead of deploying applications directly from the distribution registry of an upstream vendor, we adopt a different approach. We replicate the OCM components from the vendor's public registry into our internal private registry.

As part of the replication process, we ensure the integrity of both the OCM component manifest and the associated artifacts.
