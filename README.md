# ArgoCD updater

This repository tests how the [ArgoCD image updater](https://argocd-image-updater.readthedocs.io/) can check if there is a new image available in our remote repository and change the image version target in the deployed application via ArgoCD.

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

## Notifications

### Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
stringData:
  slack-token: SLACK_TOKEN
type: Opaque
```

### ConfigMap

Now is time to add the configuration regarding:

- **services configuration**: reference to secrets, or configuration used by a notification service
- **triggers**: what is the template that should be used when the application is at certain state
- **templates**: a message representing the application at a given state

Here's an example:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
    service.slack: |
        token: $slack-token
    trigger.on-deployed: |
      - description: Application is synced and healthy. Triggered once per commit.
        when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
        send:
        - app-deployed
    template.app-deployed: |
        email:
            subject: New version of an application {{.app.metadata.name}} is up and running.
        message: |
            {{if eq .serviceType "slack"}}:white_check_mark:{{end}} New version of *{{.app.metadata.name}}* is deployed.
        slack:
            attachments: |
                [{
                "color": "#18be52",
                "fields": [
                {
                    "title": "Author",
                    "value": "{{(call .repo.GetCommitMetadata .app.status.sync.revision).Author}}",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "{{(call .repo.GetCommitMetadata .app.status.sync.revision).Message}}",
                    "short": true
                },
                {
                    "title": "Repository",
                    "value": "{{.app.spec.source.repoURL}}",
                    "short": true
                }
                {{range $index, $image := .app.status.summary.images}}
                    {{if not $index}},{{end}}
                    {{if $index}},{{end}}
                    {
                    "title": "Version",
                    "value": "{{$image}}",
                    "short": true
                    }
                {{end}}
                ]
                }]
            deliveryPolicy: Post
            groupingKey: ""
            notifyBroadcast: false
```

### Application

Finally we need to tell to our application that should be notify when a new application it's been deployed:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: todelete
```