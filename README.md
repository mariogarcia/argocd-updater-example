# ArgoCD updater

This repository tests how the ArgoCD updater can check if there is a new image available in our remote repository and change the image version target in the deployed application via ArgoCD.

Although the best approach is to use ArgoCD image updater with the `git` mode, it's ok for the example purposes.

## Install ArgoCD

### Minikube

```shell
minikube start --memory 4096 -cpus 2
```

### ArgoCD

Create the ArgoCD namespace:

```shell
kubectl create ns argocd
```

Then install ArgoCD in your local cluster:

```shell
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml
```

Then get the initial \<password\>:

```shell
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Create a port-forwarding to expose your local ArgoCD at https://localhost:8080:

```shell
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

Login with admin/\<password\>

### ArgoCD Image Updater

Install ArgoCD image updater:

```shell
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

## Install application

The example assumes that every time we change the tag of the image and we push it to the remote repository, ArgoCD image updater will pick up the new version from the repository and will deploy it to the k8s cluster.

## Push new docker image

First we have to build the new docker image

```shell
docker build -t sqymg/argocd-updater-example:0.1.0 .
```

Then we have to push it to remote repository

```shell
docker push sqymg/argocd-updater-example:0.1.0
```

## Add Github repository to ArgoCD

You should add this repository to ArgoCD otherwise it won't know where to get the manifests from.

In ArgoCD UI go to `Settings` -> `Connect Repo` and add this repository as `https://github.com/mariogarcia/argocd-updater-example.git`

## Install application

```shell
kubectl apply -f mode-argocd
```

## Push new image version

First we have to build the new docker image

```shell
docker build -t sqymg/argocd-updater-example:0.1.1 .
```

Then we have to push it to remote repository

```shell
docker push sqymg/argocd-updater-example:0.1.1
```

Then check that the image updater will listen to the changes and deploy automatically the new version.