# openshift-workshop

## Setup

This workshop assumes you have OpenShift installed. Either OpenShift Container Platform (OCP) or [Origin (OKD)](https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md) should work. I am using Fedora 29.

Assume all commands will be run in this repositories root directory:

```
git clone https://github.com/Markieta/openshift-workshop.git
cd openshift-workshop/
```

### Docker Setup

[Get Docker CE for Fedora](https://docs.docker.com/install/linux/docker-ce/fedora/).

To use Docker as non-root (recommended), see [Post-installation steps for Linux](https://docs.docker.com/install/linux/linux-postinstall/).

Start the Docker service with systemd:

```
sudo systemctl start docker.service
```

Run a local Docker registry (v2):

```
docker run -d -p 5000:5000 --restart=always --name registry registry:2
```

You should now be able to see the registry's catalogue of repositories at: http://localhost:5000/v2/_catalog

If this is your first time creating a local Docker registry, you should see something like this:

```
{"repositories":[]}
```

### Python Flask App

Inspect the `app.py` and `Dockerfile` in this directory that we will be pushing to our local Docker registry.

Build an image from the `Dockerfile`:

```
docker build -t flask-hello-world .
```

Tag it to create a repository with the full registry location:

```
docker tag flask-hello-world localhost:5000/flask-hello-world
```

Finally, push the new repository to the registry:

```
docker push localhost:5000/flask-hello-world
```

Now if you look at http://localhost:5000/v2/_catalog you will see this:

```
{"repositories":["flask-hello-world"]}
```

### OpenShift Setup

Start the OpenShift cluster, this may take a few minutes:

```
oc cluster up
```

Launch the Flask app in OpenShift from the Docker registry.

```
oc new-app localhost:5000/flask-hello-world
```

You may also do this from the OpenShift Web Console.