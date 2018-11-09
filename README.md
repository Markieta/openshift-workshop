# openshift-workshop

## Initial Setup

This workshop assumes you have OpenShift installed. Either OpenShift Container Platform (OCP) or [Origin (OKD)](https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md) should work. I am using Fedora 29.

Assume all commands will be run in this repository's root directory:

    git clone https://github.com/Markieta/openshift-workshop.git
    cd openshift-workshop/

### Docker Setup

[Get Docker CE for Fedora](https://docs.docker.com/install/linux/docker-ce/fedora/).

To use Docker as non-root (recommended), see [Post-installation steps for Linux](https://docs.docker.com/install/linux/linux-postinstall/).

Start the Docker service with systemd:

    sudo systemctl start docker.service

Run a local Docker registry (v2):

    docker run -d -p 5000:5000 --restart=always --name registry registry:2

You should now be able to see the registry's catalogue of repositories at: <http://localhost:5000/v2/_catalog>

If this is your first time creating a local Docker registry, you should see something like this:

> {"repositories":[]}

### Python Flask App

Inspect the `app.py` and `Dockerfile` in this directory that we will be pushing to our local Docker registry.

Build an image from the `Dockerfile`:

    docker build -t flask-hello-world .

Tag it to create a repository with the full registry location:

    docker tag flask-hello-world localhost:5000/flask-hello-world

Finally, push the new repository to the registry:

    docker push localhost:5000/flask-hello-world

Now if you look at <http://localhost:5000/v2/_catalog> you will see this:

> {"repositories":["flask-hello-world"]}

### OpenShift Setup

Start the OpenShift cluster, this may take a few minutes:

    oc cluster up

Create a new project to isolate this workshop environment:

    $ oc new-project workshop
    Now using project "workshop" on server "https://127.0.0.1:8443".
    You can add applications to this project with the 'new-app' command. For example, try:

        oc new-app centos/ruby-25-centos7~https://github.com/sclorg/ruby-ex.git

    to build a new example application in Ruby.

You can always check to see which project you are currently using by running:

    $ oc project
    Using project "workshop" on server "https://127.0.0.1:8443".

Launch the Flask app in OpenShift from the Docker registry.

    oc new-app localhost:5000/flask-hello-world

You may also do this from the OpenShift Web Console.

Review that a pod, replication controller, and service were created for this app:

    $ oc get all
    NAME                            READY     STATUS    RESTARTS   AGE
    pod/flask-hello-world-1-phxk6   1/1       Running   0          1h

    NAME                                        DESIRED   CURRENT   READY     AGE
    replicationcontroller/flask-hello-world-1   1         1         1         1h

    NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
    service/flask-hello-world   ClusterIP   172.30.108.31   <none>        5000/TCP   1h

    NAME                                                   REVISION   DESIRED   CURRENT   TRIGGERED BY
    deploymentconfig.apps.openshift.io/flask-hello-world   1          1         1         config

While the service was automatically created for us because we exposed port 5000 in the `Dockerfile`, we still need to route the service to make it accessible. Create the unsecured route:

    $ oc expose service flask-hello-world
    route.route.openshift.io/flask-hello-world exposed

See that the route was created:

    $ oc get routes
    NAME                HOST/PORT                                     PATH      SERVICES            PORT       TERMINATION   WILDCARD
    flask-hello-world   flask-hello-world-workshop.127.0.0.1.nip.io             flask-hello-world   5000-tcp                 None

The route will also be displayed in the list of all resources when running `oc get all` again.

You should now be able to access the app here: <http://flask-hello-world-workshop.127.0.0.1.nip.io/>

### OpenShift Templating

For the purpose of serializing our application, for portability or later use without all of these manual steps, we can take advantage of templates in OpenShift.

We can retrieve our resources with `oc get` and serialize them into YAML, JSON, and other output formats.

Originally you would use `oc export` to accomplish this, but in newer versions of `oc` the `Command "export" is deprecated, use the oc get --export` instead.

The syntax is as follows:

    oc get <object_type> -o [ yaml | json | ... ] --export

#### flask-hello-world template

Because the pod(s) and replication controller are automatically generated by the deployment config, we do not need to extract those resources for our template. The following command will export the deployment config, service, and route information for the `flask-hello-world` app into a single YAML config file:

    oc get dc,svc,route flask-hello-world -o yaml --export > flask-hello-world.yaml

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

    $ oc delete all -l app=flask-hello-world
    pod "flask-hello-world-1-lbfbh" deleted
    replicationcontroller "flask-hello-world-1" deleted
    service "flask-hello-world" deleted
    deploymentconfig.apps.openshift.io "flask-hello-world" deleted
    route.route.openshift.io "flask-hello-world" deleted

Ensure all resources have been deleted:

    $ oc get all
    No resources found.

Create the application with out YAML template:

    $ oc create -f flask-hello-world.yaml
    deploymentconfig.apps.openshift.io/flask-hello-world created
    service/flask-hello-world created
    route.route.openshift.io/flask-hello-world created

Confirm that all of the resources were created with `oc get all` and that <http://flask-hello-world-workshop.127.0.0.1.nip.io/> is working.

#### Django Template

Here is a more complex application from Software Collections on GitHub that was designed for OpenShift. Create the Django app using the GitHub source:

    oc new-app https://github.com/openshift/django-ex.git

This may take a few seconds. You can view the status of this creating using `oc status` or from the Web Console.



After it has finished building and deploying the app (named `django-ex` by default), list all of the resources created for it:

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

One more manual step is needed to create the route that exposes the service externally:

    $ oc expose service django-ex
    route.route.openshift.io/django-ex exposed

Visit <http://django-ex-workshop.127.0.0.1.nip.io/> and you should be greeted with:

> Welcome to your Django application on OpenShift



Start building the new image from the existing build config:

    $ oc start-build django-ex
    build.build.openshift.io/django-ex-3 started