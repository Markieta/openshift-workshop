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

    {"repositories":[]}

### Python Flask App

Inspect the `app.py` and `Dockerfile` in this directory that we will be pushing to our local Docker registry.

Build an image from the `Dockerfile`:

    docker build -t flask-hello-world .

Tag it to create a repository with the full registry location:

    docker tag flask-hello-world localhost:5000/flask-hello-world

Finally, push the new repository to the registry:

    docker push localhost:5000/flask-hello-world

Now if you look at <http://localhost:5000/v2/_catalog> you will see this:

    {"repositories":["flask-hello-world"]}

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