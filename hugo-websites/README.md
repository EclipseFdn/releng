# Common files for Hugo Websites CI/CD 

## Kubernetes resources

A Hugo website has 3 Kubernetes resources:
* deployment ([documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/))
* service ([documentation](https://kubernetes.io/docs/concepts/services-networking/service/))
* route ([documentation](https://docs.okd.io/latest/networking/routes/route-configuration.html))

Each site has 2 deployements kinds: staging and production. For each, a set of 3 resources are generated. They differ on a number of points:
* the image of the pods managed by the deployment (the one for staging has basic auth as explained above) 
* the resources allocated to the pods (much lower for staging)
* the number of pod replicas (usually 1 for staging, at least 2 for production)
* the host of the route (usually *xxx-staging.eclipse.org* for staging while it’s *xxx.eclipse.org* for production)

The pods in the deployment have 2 labels (defined at the path *Deployment::spec.template.labels*): **app** and **environment**. *app* will be set to the name of the app while *environment* will be set either to *staging* or *production*. The labels are used in several locations.

Those labels will also be used in the Jenkinsfile during the *deploy* stage in order to find the deployment of the app we want to update. More on this in the section about the Jenkinsfile.

All the resources will be created in the same namespace (usually *foundation-internal-webdev-apps*). The namespace is not defined in the yaml files. If we included the namespace in the yaml files, the CI bot user would need to have elevated privileges to create/edit namespaces. This is highly undesirable. As such, it must be created manually by a cluster administrator if it does not exist already. The command line to create a namespace is:

```bash
$ oc create ns <NAMESPACE_NAME>
```

See the [OKD management documentation](https://docs.google.com/document/d/1_WKHZ0AvkUgLmDRvSZ845cWEL9SYraceIZRl2sKItKo) for more info on how to run this command (especially the section “Use OC from your laptop”).

One can easily check if the namespace already exists with the following command:

```bash
$ oc get ns <NAMESPACE_NAME>
```

## Deploy a new website

From the root folder of this git repository, just execute:

```bash
./hugo-websites/deploy.sh ../openmobility.eclipse.org/k8s/deployment.jsonnet ../jenkins-pipeline-shared/resources/org/eclipsefdn/hugoWebsite/Dockerfile
```

It expectes that a proper `deployment.jsonnet` exists. the minimal content for such a file is:

```jsonnet
local deployment = import "../../releng/hugo-websites/kube-deployment.jsonnet";

deployment.newProductionDeploymentWithStaging(
  "openmobility.eclipse.org", "openmobility-staging.eclipse.org"
)
```