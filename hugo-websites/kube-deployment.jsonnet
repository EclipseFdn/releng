local newDeployment(hostname, routePath, appname, env) = {
  namespace::  "foundation-internal-webdev-apps",
  serviceName:: std.strReplace(appname, ".", "-"),
  labels:: {
    app: appname,
    environment: env,
  },
  deployment: {
    apiVersion: "apps/v1",
    kind: "Deployment",
    metadata: {
      name: appname,
      namespace: $.namespace,
      labels: $.labels,
    },
    spec: {
      selector: {
        matchLabels: $.labels,
      },
      replicas: if (env == "production") then 2 else 1,
      template: {
        metadata: {
          labels: $.labels,
        },
        spec: {
          affinity: {
            nodeAffinity: {
              preferredDuringSchedulingIgnoredDuringExecution: [
                {
                  preference: {
                    matchExpressions: [
                      {
                        key: "speed",
                        operator: "NotIn",
                        values: [ "fast" ],
                      },
                    ],
                  },
                  weight: 1
                },
              ],
            },
          },
          containers: [
            {
              name: "nginx",
              image: "eclipsefdn/%s:%s" % [appname, if (env == "production") then "latest" else "staging-latest" ],
              imagePullPolicy: "Always",
              ports: [
                {
                  containerPort: 8080,
                },
              ],
              resources: {
                limits: {
                  cpu: if (env == "production") then 1 else "200m",
                  memory: if (env == "production") then "256Mi" else "128Mi",
                },
                requests: {
                  cpu: if (env == "production") then "200m" else "50m",
                  memory: if (env == "production") then "128Mi" else "64Mi",
                },
              },
            },
          ],
        },
      },
    }
  },
  service: {
    apiVersion: "v1",
    kind: "Service",
    metadata: {
      name: $.serviceName,
      namespace: $.namespace,
      labels: $.labels,
    },
    spec: {
      ports: [
        {
          name: "http",
          port: 80,
          protocol: "TCP",
          targetPort: 8080,
        },
      ],
      selector: $.labels,
    },
  },
  route: {
    apiVersion: "route.openshift.io/v1",
    kind: "Route",
    metadata: {
      name: appname,
      namespace: $.namespace,
      annotations: {
        "haproxy.router.openshift.io/timeout": "20s",
        "haproxy.router.openshift.io/disable_cookies": "true",
        "haproxy.router.openshift.io/balance": "roundrobin",
        "haproxy.router.openshift.io/rewrite-target": "/",
      },
    },
    spec: {
      host: hostname,
      path: routePath,
      port: {
        targetPort: "http",
      },
      tls: {
        insecureEdgeTerminationPolicy: "Redirect",
        termination: "edge",
      },
      to: {
        kind: "Service",
        name: $.serviceName,
        weight: 100,
      },
    },
  },
  kube: [self.deployment, self.service, self.route],
};

{
  newDeployment:: newDeployment,
  
  newProductionDeploymentWithStaging(prodHostname, stagingHostname, appName=prodHostname, stagingAppName="%s-staging" % appName, routePath="/"):: 
    newDeployment(prodHostname, routePath, appName, "production").kube 
    + newDeployment(stagingHostname, routePath, stagingAppName, "staging").kube,

}