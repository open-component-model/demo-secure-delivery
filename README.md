# Secure software delivery with Flux and Open Component Model

## Fully guided walkthrough

![workflow](./docs/images/diagram.png)

This walkthrough deploys a full end-to-end pipeline demonstrating how OCM and Flux can be employed to deploy applications in air-gapped environments.

The demo environment consists of Gitea, Tekton, Flux and the OCM controller.
Two Gitea organizations are created:
- [software-provider](https://gitea.ocm.dev/software-provider)
- [software-consumer](https://gitea.ocm.dev/software-consumer)

The provider organization contains a repository which models the `podinfo` application. When a new release is created a Tekton pipeline will be triggered that builds the component and pushes it to the [software provider's OCI registry](https://gitea.ocm.dev/software-provider/-/packages).

## Software Consumer

The software consumer organization models an air-gapped scenario where applications are deployed from a secure OCI registry rather than directly from an arbitrary upstream source.

The software consumer organization contains a repository named [ocm-applications](https://gitea.ocm.dev/software-consumer/ocm-applications). During the setup of the demo a PR is created which contains the Kubernetes manifests required to deploy the component published by the software provider.

Once this pull request is merged the Flux machinery will deploy the dependency `weave-gitops` and subsequently the `podinfo` component. The [weave-gitops dashboard](https://weave-gitops.ocm.dev) can be used to understand the state of the cluster.

### Walkthrough

Instructions are provided to guide you through the process of deploying the demo environment, cutting a release for "podinfo," verifying the release automation, installing the component, viewing the Weave GitOps dashboard, accessing the deployed application, applying configuration changes, monitoring the application update, and cutting a new release with updated features.

#### 1. Setup demo environment

To deploy the demo environment execute the following:

`make run`

Once the environment has been created, login to Gitea using the following credentials:

```
username: ocm-admin
password: password
```

#### 2. Cut a release for `podinfo`

![release](./docs/images/publish.png)

Next navigate to: https://gitea.ocm.dev/software-provider/podinfo-component/releases and click "New Release".

Enter "v1.0.0" for both the tag name and release name, and then click "Publish Release".

#### 3. Verify the release

![ci](./docs/images/release_automation.png)

Once the release is published, navigate to https://ci.ocm.dev/#/namespaces/tekton-pipelines/pipelineruns and follow the progress of the release automation.

#### 4. Install the Component

![install](./docs/images/install.png)

When the release pipeline has been completed we can install the component. Navigate to https://gitea.ocm.dev/software-consumer/ocm-applications/pulls/1 and merge the pull request.

#### 5. View the Weave GitOps Dashboard

![weave-gitops](./docs/images/weave-gitops.png)

With a minute or so Flux will reconcile the Weave GitOps component and the dashboard will be accessible at https://weave-gitops.ocm.dev. You can login with username: `admin` and password `password`.

#### 5. View the application

![podinfo](./docs/images/application.png)

We can view the `podinfo` Helm release that's been deployed in the default namespace: https://weave-gitops.ocm.dev/helm_release/graph?clusterName=Default&name=podinfo&namespace=default

We can also view the running application at https://podinfo.ocm.dev

#### 6. Apply configuration

![configure](./docs/images/configure.png)

The application can be configured using the parameters exposed in `values.yaml`. Now that podinfo is deployed we can tweak a few parameters, navigate to
https://gitea.ocm.dev/software-consumer/ocm-applications/_edit/main/values.yaml
and add the following:

```yaml
podinfo:
  replicas: 2
  message: "Hello Open Component Model!"
  serviceAccountName: ocm-ops
weave-gitops:
  serviceAccountName: ocm-ops
```

#### 7. View the configured application

![update](./docs/images/update.png)

The changes will soon be reconciled by Flux and visible at https://podinfo.ocm.dev. Note how the pod id changes now that we have 2 replicas of our application running.

#### 8. Cut a new release

Let's jump back to the provider repository and cut another release. This release will contain a new feature that changes the image displayed by the podinfo application. Follow the same process as before to create a release, bumping the version to `v1.1.0`.

#### 9. Verify the release

Once the release is published, navigate to https://ci.ocm.dev/#/namespaces/tekton-pipelines/pipelineruns and follow the progress of the release automation.

#### 10. Monitor the application update

![update-wego](./docs/images/update-wego.png)

Jump back to https://weave-gitops.ocm.dev to view the rollout of the new release.

#### 11. View the updated application

![update-ocm](./docs/images/update-ocm.png)

Finally, navigate to https://podinfo.ocm.dev which now displays the OCM logo in place of the cuttlefish and the updated application version of 6.3.6

### Conclusion

By leveraging the capabilities of Gitea, Tekton, Flux, and the OCM controller, this demo showcases the seamless deployment of components and dependencies in a secure manner. The use of secure OCI registries and automated release pipelines ensures the integrity and reliability of the deployment process.

Users can easily set up the demo environment, cut releases, monitor release automation, view the Weave GitOps dashboard and observe the deployment and update of applications. We have presented a practical illustration of how OCM and Flux can be employed to facilitate the deployment and management of applications in air-gapped environments, offering a robust and efficient solution for secure software delivery.
