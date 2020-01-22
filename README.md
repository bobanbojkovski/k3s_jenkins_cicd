# Build and deploy Jenkins ci/cd to [k3s](https://k3s.io/)

### Prerequisites

* [Installed and configured (master-worker) kubernetes](https://github.com/bobanbojkovski/k3s) - [k3s](https://k3s.io/) cluster.
* Installed Docker to build and push an image to registry.


### Demo uses Jenkins helm chart to build and deploy the ci/cd tool to kubernetes

Jenkins helm chart details are available at [Jenkins Helm Chart](https://hub.helm.sh/charts/stable/jenkins)

Start with cloning the helm charts.
```
git clone https://github.com/helm/charts.git
```

Jenkins charts are located under charts/stable/jenkins/  
Create two additional directories and backup default values.yaml file for reference purpose.

```
mkdir manifests values
cp values.yaml values
```

Update values.yaml then generate deployment files in ./manifests directory.

```
helm template \
  --values ./values.yaml \
  --output-dir ./manifests \
    ./
```

output:
```
wrote ./manifests/jenkins/templates/secret.yaml
wrote ./manifests/jenkins/templates/config.yaml
wrote ./manifests/jenkins/templates/tests/test-config.yaml
wrote ./manifests/jenkins/templates/home-pvc.yaml
wrote ./manifests/jenkins/templates/service-account.yaml
wrote ./manifests/jenkins/templates/rbac.yaml
wrote ./manifests/jenkins/templates/jenkins-agent-svc.yaml
wrote ./manifests/jenkins/templates/jenkins-master-svc.yaml
wrote ./manifests/jenkins/templates/tests/jenkins-test.yaml
wrote ./manifests/jenkins/templates/jenkins-master-deployment.yaml
wrote ./manifests/jenkins/templates/jenkins-master-ingress.yaml
```

To manage a storage on master node, create PersistentVolume (PV) pointing to local path,  
for example: /volumes/jenkins_home

pv.yaml
```
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-local-pv
spec:
  capacity:
    storage: 8Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: jenkins-local-storage
  hostPath:
    path: /volumes/jenkins_home
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/master
          operator: In
          values:
          - "true"

```

Create dedicated namespace 'jenkins'.

ns.yaml
```
---
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
```

kubectl apply -f ns.yaml

Complete jenkins dir structure looks like:
```
├── CHANGELOG.md
├── Chart.yaml
├── OWNERS
├── README.md
├── ci
│   ├── casc-values.yaml
│   └── default-values.yaml
├── manifests
│   └── jenkins
│       └── templates
│           ├── config.yaml
│           ├── home-pvc.yaml
│           ├── jenkins-agent-svc.yaml
│           ├── jenkins-master-deployment.yaml
│           ├── jenkins-master-ingress.yaml
│           ├── jenkins-master-svc.yaml
│           ├── pv.yaml
│           ├── rbac.yaml
│           ├── secret.yaml
│           ├── service-account.yaml
│           └── tests
│               ├── jenkins-test.yaml
│               └── test-config.yaml
├── templates
│   ├── NOTES.txt
│   ├── _helpers.tpl
│   ├── config.yaml
│   ├── deprecation.yaml
│   ├── home-pvc.yaml
│   ├── jcasc-config.yaml
│   ├── jenkins-agent-svc.yaml
│   ├── jenkins-backup-cronjob.yaml
│   ├── jenkins-backup-rbac.yaml
│   ├── jenkins-master-alerting-rules.yaml
│   ├── jenkins-master-backendconfig.yaml
│   ├── jenkins-master-deployment.yaml
│   ├── jenkins-master-ingress.yaml
│   ├── jenkins-master-networkpolicy.yaml
│   ├── jenkins-master-route.yaml
│   ├── jenkins-master-servicemonitor.yaml
│   ├── jenkins-master-svc.yaml
│   ├── jobs.yaml
│   ├── rbac.yaml
│   ├── secret.yaml
│   ├── service-account-agent.yaml
│   ├── service-account.yaml
│   └── tests
│       ├── jenkins-test.yaml
│       └── test-config.yaml
├── values
│   └── values.yaml
└── values.yaml
```

Deploy the Jenkins files running following command:  
kubectl apply --recursive -f ./manifests/jenkins/templates  

Watch the pods creation:  
kubectl get pod -n jenkins -o wide --watch



### Sample Jenkinsfile (pipeline)

Pipeline stages:  
Clone repository -->  Build image  -->  Test image  -->  Push image  -->  Deploy image  

Test image stage covers api accessibility.


### nginx ingress tls with hashicorp vault

Start pre-configured dev vault server (for test/development puropse):  
```
download vault zip from https://releases.hashicorp.com/vault/
curl -OL https://releases.hashicorp.com/vault/1.3.1/vault_1.3.1_linux_amd64.zip
	
unzip vault_1.3.1_linux_amd64.zip
mv vault /usr/local/bin/
	
echo "export VAULT_ADDR=http://127.0.0.1:8200" >> ~/.bashrc
	
vault server -dev &  
```

Generate Root CA, create a Role (pki.sh snippet):  
```
vault write -field=certificate pki/root/generate/internal \
        common_name="example.com" \
        ttl=87600h

vault write pki/roles/example-dot-com \
        allowed_domains="example.com" \
        allow_subdomains=true \
        max_ttl="720h"
```

Request certificates (certs.sh snippet):  
```
vault write -format=json pki/issue/example-dot-com \
        common_name="jenkins.example.com"
```

Create jenkins-secret tls secret using the certification and private_key data fetched in previous step:  
```
kubectl create secret tls jenkins-secret \
        --key /tmp/tls.key --cert /tmp/tls.crt \
        -n jenkins --dry-run -o yaml | kubectl apply -f -
```

Edit nginx ingress definiton adding tls block, for example:  
kubectl edit ing release-name-jenkins -n jenkins
```
spec:
  tls:
  - hosts:
    - jenkins.example.com
    secretName: jenkins-secret
```




