# openshift-workshop

## Initial Setup

This workshop assumes you have OpenShift installed. Either OpenShift Container Platform (OCP) or [Origin (OKD)](https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md) should work. I am using Fedora 29.

Assume all commands will be run in this repository's root directory:

```bash
git clone https://github.com/Markieta/openshift-workshop.git
cd openshift-workshop/
```

## Docker Setup

[Get Docker CE for Fedora](https://docs.docker.com/install/linux/docker-ce/fedora/).

To use Docker as non-root (recommended), see [Post-installation steps for Linux](https://docs.docker.com/install/linux/linux-postinstall/).

Start the Docker service with systemd:

```bash
sudo systemctl start docker.service
```

Run a local Docker registry (v2):

```bash
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

You should now be able to see the registry's catalogue of repositories at: <http://localhost:5000/v2/_catalog>

If this is your first time creating a local Docker registry, you should see something like this:

> {"repositories":[]}

## Python Flask App

Inspect the `app.py` and `Dockerfile` in this directory that we will be pushing to our local Docker registry.

Build an image from the `Dockerfile`:

```bash
docker build -t flask-hello-world .
```

Tag it to create a repository with the full registry location:

```bash
docker tag flask-hello-world localhost:5000/flask-hello-world
```

Finally, push the new repository to the registry:

```bash
docker push localhost:5000/flask-hello-world
```

Now if you look at <http://localhost:5000/v2/_catalog> you will see this:

> {"repositories":["flask-hello-world"]}

## OpenShift Setup

Start the OpenShift cluster, this may take a few minutes:

```bash
oc cluster up
```

Create a new project to isolate this workshop environment:

```bash
$ oc new-project workshop
Now using project "workshop" on server "https://127.0.0.1:8443".
You can add applications to this project with the 'new-app' command. For example, try:
```

```bash
oc new-app centos/ruby-25-centos7~https://github.com/sclorg/ruby-ex.git
```

```bash
to build a new example application in Ruby.
```

You can always check to see which project you are currently using by running:

```bash
$ oc project
Using project "workshop" on server "https://127.0.0.1:8443".
```

Launch the Flask app in OpenShift from the Docker registry.

```bash
oc new-app localhost:5000/flask-hello-world
```

You may also do this from the OpenShift Web Console.

Review that a pod, replication controller, and service were created for this app:

```bash
$ oc get all
NAME                            READY     STATUS    RESTARTS   AGE
pod/flask-hello-world-1-phxk6   1/1       Running   0          1h

NAME                                        DESIRED   CURRENT   READY     AGE
replicationcontroller/flask-hello-world-1   1         1         1         1h

NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/flask-hello-world   ClusterIP   172.30.108.31   <none>        5000/TCP   1h

NAME                                                   REVISION   DESIRED   CURRENT   TRIGGERED BY
deploymentconfig.apps.openshift.io/flask-hello-world   1          1         1         config
```

While the service was automatically created for us because we exposed port 5000 in the `Dockerfile`, we still need to route the service to make it accessible. Create the unsecured route:

```bash
$ oc expose service flask-hello-world
route.route.openshift.io/flask-hello-world exposed
```

See that the route was created:

```bash
$ oc get routes
NAME                HOST/PORT                                     PATH      SERVICES            PORT       TERMINATION   WILDCARD
flask-hello-world   flask-hello-world-workshop.127.0.0.1.nip.io             flask-hello-world   5000-tcp                 None
```

The route will also be displayed in the list of all resources when running `oc get all` again.

You should now be able to access the app here: <http://flask-hello-world-workshop.127.0.0.1.nip.io/>

## OpenShift Templating

For the purpose of serializing our application, for portability or later use without all of these manual steps, we can take advantage of templates in OpenShift.

We can retrieve our resources with `oc get` and serialize them into YAML, JSON, and other output formats.

Originally you would use `oc export` to accomplish this, but in newer versions of `oc` the `Command "export" is deprecated, use the oc get --export` instead.

The syntax is as follows:

```bash
oc get <object_type> -o [ yaml | json | ... ] --export
```

### flask-hello-world template

Because the pod(s) and replication controller are automatically generated by the deployment config, we do not need to extract those resources for our template. The following command will export the deployment config, service, and route information for the `flask-hello-world` app into a single YAML config file:

```bash
oc get dc,svc,route flask-hello-world -o yaml --export > flask-hello-world.yaml
```

Here's an example of what that file might end up looking like:

```yaml
apiVersion: v1
items:
- apiVersion: apps.openshift.io/v1
  kind: DeploymentConfig
  metadata:
    annotations:
      openshift.io/generated-by: OpenShiftNewApp
    creationTimestamp: null
    generation: 1
    labels:
      app: flask-hello-world
    name: flask-hello-world
    selfLink: /apis/apps.openshift.io/v1/namespaces/workshop/deploymentconfigs/flask-hello-world
  spec:
    replicas: 1
    revisionHistoryLimit: 10
    selector:
      app: flask-hello-world
      deploymentconfig: flask-hello-world
    strategy:
      activeDeadlineSeconds: 21600
      resources: {}
      rollingParams:
        intervalSeconds: 1
        maxSurge: 25%
        maxUnavailable: 25%
        timeoutSeconds: 600
        updatePeriodSeconds: 1
      type: Rolling
    template:
      metadata:
        annotations:
          openshift.io/generated-by: OpenShiftNewApp
        creationTimestamp: null
        labels:
          app: flask-hello-world
          deploymentconfig: flask-hello-world
      spec:
        containers:
        - image: localhost:5000/flask-hello-world:latest
          imagePullPolicy: Always
          name: flask-hello-world
          ports:
          - containerPort: 5000
            protocol: TCP
          resources: {}
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
        dnsPolicy: ClusterFirst
        restartPolicy: Always
        schedulerName: default-scheduler
        securityContext: {}
        terminationGracePeriodSeconds: 30
    test: false
    triggers:
    - type: ConfigChange
  status:
    availableReplicas: 0
    latestVersion: 0
    observedGeneration: 0
    replicas: 0
    unavailableReplicas: 0
    updatedReplicas: 0
- apiVersion: v1
  kind: Service
  metadata:
    annotations:
      openshift.io/generated-by: OpenShiftNewApp
    creationTimestamp: null
    labels:
      app: flask-hello-world
    name: flask-hello-world
    selfLink: /api/v1/namespaces/workshop/services/flask-hello-world
  spec:
    ports:
    - name: 5000-tcp
      port: 5000
      protocol: TCP
      targetPort: 5000
    selector:
      app: flask-hello-world
      deploymentconfig: flask-hello-world
    sessionAffinity: None
    type: ClusterIP
  status:
    loadBalancer: {}
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    annotations:
      openshift.io/host.generated: "true"
    creationTimestamp: null
    labels:
      app: flask-hello-world
    name: flask-hello-world
    selfLink: /apis/route.openshift.io/v1/namespaces/workshop/routes/flask-hello-world
  spec:
    host: flask-hello-world-workshop.127.0.0.1.nip.io
    port:
      targetPort: 5000-tcp
    to:
      kind: Service
      name: flask-hello-world
      weight: 100
    wildcardPolicy: None
  status:
    ingress: null
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
```

There is a lot of unnecessary information here that we can probably remove. Such as runtime/environment-specific information.

Let's test the template to ensure it works. First, delete all of the resources relating to the `flask-hello-world` app:

```bash
$ oc delete all -l app=flask-hello-world
pod "flask-hello-world-1-lbfbh" deleted
replicationcontroller "flask-hello-world-1" deleted
service "flask-hello-world" deleted
deploymentconfig.apps.openshift.io "flask-hello-world" deleted
route.route.openshift.io "flask-hello-world" deleted
```

Ensure all resources have been deleted:

```bash
$ oc get all
No resources found.
```

Create the application with out YAML template:

```bash
$ oc create -f flask-hello-world.yaml
deploymentconfig.apps.openshift.io/flask-hello-world created
service/flask-hello-world created
route.route.openshift.io/flask-hello-world created
```

Confirm that all of the resources were created with `oc get all` and that <http://flask-hello-world-workshop.127.0.0.1.nip.io/> is working.

### Django Template

Here is a more complex application from Software Collections on GitHub that was designed for OpenShift. Create the Django app using the GitHub source:

```bash
oc new-app https://github.com/openshift/django-ex.git
```

This may take a few seconds. You can view the status of this creating using `oc status` or from the Web Console.

After it has finished building and deploying the app (named `django-ex` by default), list all of the resources created for it:

```bash
$ oc get all -l app=django-ex
NAME                    READY     STATUS    RESTARTS   AGE
pod/django-ex-1-s5glf   1/1       Running   0          19m

NAME                                DESIRED   CURRENT   READY     AGE
replicationcontroller/django-ex-1   1         1         1         19m

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/django-ex   ClusterIP   172.30.134.28   <none>        8080/TCP   20m

NAME                                           REVISION   DESIRED   CURRENT   TRIGGERED BY
deploymentconfig.apps.openshift.io/django-ex   1          1         1         config,image(django-ex:latest)

NAME                                       TYPE      FROM      LATEST
buildconfig.build.openshift.io/django-ex   Source    Git       1

NAME                                   TYPE      FROM          STATUS     STARTED          DURATION
build.build.openshift.io/django-ex-1   Source    Git@ab765c5   Complete   20 minutes ago   22s

NAME                                       DOCKER REPO                          TAGS      UPDATED
imagestream.image.openshift.io/django-ex   172.30.1.1:5000/workshop/django-ex   latest    19 minutes ago
```

One more manual step is needed to create the route that exposes the service externally:

```bash
$ oc expose service django-ex
route.route.openshift.io/django-ex exposed
```

Visit <http://django-ex-workshop.127.0.0.1.nip.io/> and you should be greeted with:

> Welcome to your Django application on OpenShift

Because the pod(s) and replication controller are automatically generated by the deployment config, we do not need to extract those resources for our template.

The following commands will export different resource information for the `django-ex` app into separate YAML config files:

```bash
oc get dc django-ex -o yaml --export > django-ex-deploymentconfig.yaml
```

```yaml
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  annotations:
    openshift.io/generated-by: OpenShiftNewApp
  creationTimestamp: null
  generation: 1
  labels:
    app: django-ex
  name: django-ex
  selfLink: /apis/apps.openshift.io/v1/namespaces/workshop/deploymentconfigs/django-ex
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    app: django-ex
    deploymentconfig: django-ex
  strategy:
    activeDeadlineSeconds: 21600
    resources: {}
    rollingParams:
      intervalSeconds: 1
      maxSurge: 25%
      maxUnavailable: 25%
      timeoutSeconds: 600
      updatePeriodSeconds: 1
    type: Rolling
  template:
    metadata:
      annotations:
        openshift.io/generated-by: OpenShiftNewApp
      creationTimestamp: null
      labels:
        app: django-ex
        deploymentconfig: django-ex
    spec:
      containers:
      - image: 172.30.1.1:5000/workshop/django-ex@sha256:1739df91974ad1eca71f0b163813964840e2e92b7639e1e5d33379943976cd33
        imagePullPolicy: Always
        name: django-ex
        ports:
        - containerPort: 8080
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
  test: false
  triggers:
  - type: ConfigChange
  - imageChangeParams:
      automatic: true
      containerNames:
      - django-ex
      from:
        kind: ImageStreamTag
        name: django-ex:latest
        namespace: workshop
    type: ImageChange
status:
  availableReplicas: 0
  latestVersion: 0
  observedGeneration: 0
  replicas: 0
  unavailableReplicas: 0
  updatedReplicas: 0
```

```bash
oc get svc django-ex -o yaml --export > django-ex-service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    openshift.io/generated-by: OpenShiftNewApp
  creationTimestamp: null
  labels:
    app: django-ex
  name: django-ex
  selfLink: /api/v1/namespaces/workshop/services/django-ex
spec:
  ports:
  - name: 8080-tcp
    port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: django-ex
    deploymentconfig: django-ex
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```

```bash
oc get route django-ex -o yaml --export > django-ex-route.yaml
```

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    openshift.io/host.generated: "true"
  creationTimestamp: null
  labels:
    app: django-ex
  name: django-ex
  selfLink: /apis/route.openshift.io/v1/namespaces/workshop/routes/django-ex
spec:
  host: django-ex-workshop.127.0.0.1.nip.io
  port:
    targetPort: 8080-tcp
  to:
    kind: Service
    name: django-ex
    weight: 100
  wildcardPolicy: None
status:
  ingress: null
```

```bash
oc get is django-ex -o yaml --export > django-ex-imagestream.yaml
```

```yaml
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  annotations:
    openshift.io/generated-by: OpenShiftNewApp
  creationTimestamp: null
  generation: 1
  labels:
    app: django-ex
  name: django-ex
  selfLink: /apis/image.openshift.io/v1/namespaces/workshop/imagestreams/django-ex
spec:
  lookupPolicy:
    local: false
status:
  dockerImageRepository: 172.30.1.1:5000/django-ex
```

```bash
oc get bc django-ex -o yaml --export > django-ex-buildconfig.yaml
```

```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  annotations:
    openshift.io/generated-by: OpenShiftNewApp
  creationTimestamp: null
  labels:
    app: django-ex
  name: django-ex
  selfLink: /apis/build.openshift.io/v1/namespaces/workshop/buildconfigs/django-ex
spec:
  failedBuildsHistoryLimit: 5
  nodeSelector: null
  output:
    to:
      kind: ImageStreamTag
      name: django-ex:latest
  postCommit: {}
  resources: {}
  runPolicy: Serial
  source:
    git:
      uri: https://github.com/openshift/django-ex.git
    type: Git
  strategy:
    sourceStrategy:
      from:
        kind: ImageStreamTag
        name: python:3.6
        namespace: openshift
    type: Source
  successfulBuildsHistoryLimit: 5
  triggers:
  - github:
      secret: ####################
    type: GitHub
  - generic:
      secret: ####################
    type: Generic
  - type: ConfigChange
  - imageChange:
      lastTriggeredImageID: 172.30.1.1:5000/openshift/python@sha256:9f044e4c0ee877dd9b2e0108d8b33f034977f87a746cfccb7defc9a588144b2d
    type: ImageChange
status:
  lastVersion: 1
```

Let's delete the Django app and start from scratch to test our newly generated YAML template files:

```bash
$ oc delete all -l app=django-ex
pod "django-ex-1-mmrrs" deleted
replicationcontroller "django-ex-1" deleted
service "django-ex" deleted
deploymentconfig.apps.openshift.io "django-ex" deleted
buildconfig.build.openshift.io "django-ex" deleted
build.build.openshift.io "django-ex-1" deleted
imagestream.image.openshift.io "django-ex" deleted
route.route.openshift.io "django-ex" deleted
```

Create the Django app using our 5 YAML files (deployment config, service, route, image stream, and build config):

```bash
$ oc create -f django-ex-deploymentconfig.yaml,django-ex-service.yaml,django-ex-route.yaml,django-ex-imagestream.yaml,django-ex-buildconfig.yaml
deploymentconfig.apps.openshift.io/django-ex created
service/django-ex created
route.route.openshift.io/django-ex created
imagestream.image.openshift.io/django-ex created
buildconfig.build.openshift.io/django-ex created
```

Start building the new image from the existing build config:

```bash
$ oc start-build django-ex
build.build.openshift.io/django-ex-3 started
```

After a few seconds the build will complete and you should be able to access: <http://django-ex-workshop.127.0.0.1.nip.io/> as before.

## OpenShift Jenkins Pipeline (using DSL Plugin)

This section will demonstrate how to create a Jenkins build pipeline of a complex app.

### Project and Jenkins Setup

To avoid collisions with our current environment, let's create two new projects:

```bash
oc new-project pipeline-workshop-prod
oc new-project pipeline-workshop-dev
```

_Continue using the `-dev` namespace throughout unless otherwise specified._

Deploy Jenkins using ephemeral storage:

```bash
oc new-app jenkins-ephemeral
```

### Wekan

The app we will be building in our pipeline is called [Wekan](https://wekan.github.io/). Wekan is an open-source kanban. I chose Wekan because out of all the open-source kanban tools I have tested, Wekan had the best design and functionality. I think it is a neat alternative to [Trello](https://trello.com/en) if you're looking for something free, open-source, and can be self-hosted.

For this walkthrough, I have forked the [official Wekan repository](https://github.com/wekan/wekan) in order to make changes to it. [Here is my forked version](https://github.com/Markieta/wekan).

### Wekan Resource Provisioning

Lucky for us, the Wekan repository contains an ["OpenShift template for Wekan backed by MongoDB"](https://github.com/Markieta/wekan/tree/pipeline-workshop/openshift).

Create a template in our `pipeline-workshop-dev` namespace using the YAML file:

```bash
$ oc create -f https://raw.githubusercontent.com/Markieta/wekan/pipeline-workshop/openshift/wekan.yml
template.template.openshift.io/wekan-mongodb-persistent created
```

Use the provided template to provision all required resources. You will need to provide a value for the Fully Qualified Domain Name (**FQDN**) parameter:

```bash
oc new-app --template=wekan-mongodb-persistent -p FQDN="wekan.localhost"
```

You should now have a working Wekan instance here: <https://wekan.localhost/>

### BuildConfig and Pipeline

A little bit more work is required to automate the build process of Wekan.

Create a BuildConfig using my forked repository on the branch named `pipeline-workshop`:

```bash
oc new-build https://github.com/Markieta/wekan.git#pipeline-workshop
```

You will now have a BuildConfig named `wekan`. We want Jenkins to start a build with this BuildConfig whenever the pipeline starts (either manually or after a code push).

Another BuildConfig is needed for configuring the Jenkins pipeline. Create a file named `wekan-pipeline.yaml` with the contents below (change the secret to some random alphanumeric string):

```yaml
kind: "BuildConfig"
apiVersion: "v1"
metadata:
  name: "wekan-pipeline"
spec:
  source:
    git:
      ref: pipeline-workshop
      uri: 'https://github.com/Markieta/wekan.git'
    type: Git
  triggers:
    - type: GitHub
      github:
        secret: ################
  strategy:
    jenkinsPipelineStrategy:
      jenkinsfile: |-
        pipeline {
          agent any

          stages {
            stage('Build') {
              steps {
                script {
                  openshift.withCluster() {
                    openshift.withProject("pipeline-workshop-dev"){
                      def buildSelector = openshift.selector("bc", "wekan").startBuild()
                      buildSelector.logs('-f')
                    }
                  }
                }
              }
            }
            stage('Promote to Production?') {
              steps {
                timeout(time:15, unit:'MINUTES') {
                  input message: "Promote to Production?", ok: "Promote"
                }
                script {
                  openshift.withCluster() {
                    openshift.tag("pipeline-workshop-dev/wekan:latest", "pipeline-workshop-prod/wekan:promoteToProd")
                  }
                }
              }
            }
          }
        }
    type: JenkinsPipeline
```

Create the wekan-pipeline BuildConfig:

```bash
$ oc create -f wekan-pipeline.yaml
buildconfig.build.openshift.io/wekan-pipeline created
```

### Triggering Builds with GitHub Webhooks and UltraHook Proxy

In order to make webhooks work on localhost (for development purposes only), register with and install [UltraHook](http://www.ultrahook.com/). UltraHook will create a proxy your localhost on whichever specified port you want, allowing GitHub to send JSON data to our local machines when code is pushed to our branch.

```bash
gem install ultrahook
```

Once installed, you can start the proxy by running:

```bash
$ ultrahook openshift https://localhost:8443
Authenticated as <webhook_namespace>
Forwarding activated...
http://openshift.<webhook_namespace>.ultrahook.com -> https://localhost:8443
```

You should now be able to use the UltraHook URL in place of <https://localhost:8443> when entering your webhook URL into GitHub. Leave this terminal session up and running while testing anything involving webhooks.

```bash
oc describe bc wekan-pipeline
```

Retrieve the GitHub webhook, replacing localhost (or 127.0.0.1) with the UltraHook URL. It should look something like this:

> `http://openshift.<webhook_namespace>.ultrahook.com/apis/build.openshift.io/v1/namespaces/pipeline-workshop-dev/buildconfigs/wekan-pipeline/webhooks/<secret>/github`

_Substitute \<webhook_namespace> for your UltraHook name and \<secret> for the secret you entered in the `wekan-pipeline` BuildConfig._

In our forked Wekan repository settings on GitHub, under the Webhooks section, select: **Add webhook**. Enter the above URL for **Payload URL**, . Switch **Content type** to **application/json** and click **Add webhook**.

If everything was done correctly. You should now see HTTP status 200 responses and green lights from GitHub. Whenever changes are pushed to the `wekan-pipeline` branch, a build should automatically be triggered.

### Service Account Role-Based Access Control (RBAC)

When promoting the image to the production environment, we need to give the Jenkins service account access to that namespace. Give the service account `edit` permission in the `pipeline-workshop-prod` namespace:

```bash
oc policy add-role-to-user edit system:serviceaccount:pipeline-workshop-dev:jenkins -n pipeline-workshop
-prod
```

_This is a very broad role, in reality, use more specific roles to give the service account less permissions overall._