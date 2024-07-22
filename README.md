**note:** 해당 가이드는 지속적으로 수정 예정.
## Release Note
1.0 - 첫번째 공개

1.1(Now) - PORT 수정 가능

# What is image-prune?
k8s 를 이용하다보면 Node들에 container image들이 쌓이게 되는데 이를 정리하는 CronJob 이다

기능은 옵션을 통해 docker 뿐만아니라 crictl 명령어를 이용하여 image pruning 을 진행할 수 있으며,
Control Plane 도 정리할지 안할지 옵션을 통해 선택할 수 있다.


# How to use this image

## 1. Default cronjob yaml
아래는 기본적인 yaml 파일이며 command 배열과 mountPath, API_TOKEN, API_URL, KEY_NAME, defaultMode는 필수 옵션이다.
```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: image-prune
spec:
  schedule: "0 0 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: image-prune
            image: pangyeons/image-prune:1.1
            imagePullPolicy: IfNotPresent
            command: # 아래 command 배열 수정금지
            - /bin/sh
            - -c
            - chmod +x image_prune.sh; /image_prune.sh
            volumeMounts:
            - mountPath: /etc/sshkey # 수정 금지
              name: secret-sshkey
            env:
            - name: API_TOKEN # 삭제 금지 필수 옵션
              valueFrom:
                secretKeyRef:
                  key:
                  name: 
            - name: API_URL # 삭제 금지 필수 옵션
              value: ""
            - name: KEY_NAME # 삭제 금지 필수 옵션
              value: ""
            - name: CRI_TYPE
              value: ""
            - name: CONTROL_PLANE
              value: ""
            - name: OS_USER
              value: ""
            - name: PORT
              value: ""
          restartPolicy: OnFailure
          volumes:
          - name: secret-sshkey
            secret:
              defaultMode: 0600 # 수정금지
              secretName:

```

## 2. ssh key 생성 및 등록
ssh-keygen 을 통해 ssh key 생성
```
ssh-keygen -t rsa # ex) id_rsa, id_rsa.pub 생성
```

생성 후 나온 public key 모든 node에 등록
```
# id_rsa.pub 등록
vi ~/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDNbPyWARlsD1OmjgHcQAewXvmTbAJYAYMlRgjgUKu69uVyKB8ZS0n3KuLJy9JoTF4y/VOL5DTCU2TFb1A1eIhM4Ox5sPoNTWIG7
```

생성한 ssh private key를 k8s secret에 등록
```
kubectl create secret generic sshkey --from-file=privatekey=./id_rsa
```



## 3. k8s API를 사용할 API Token 생성
`현재 Ready 중인 Node 및 Master/Worker Node 구분을 위함`

API Token 생성을 위한 Serivce Account 생성 및 API 조회에 필요한 Role 부여
```
vi test-token.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: test-token
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-nodes
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes-binding
subjects:
- kind: ServiceAccount
  name: test-token
  namespace: default
roleRef:
  kind: ClusterRole
  name: read-nodes
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: test-token-secret
  namespace: default
  annotations:
    kubernetes.io/service-account.name: test-token
```


생성한 계정에 대한 API Token 조회
```
API_TOKEN=$(kubectl get secret test-token-secret -o jsonpath="{.data.token}" | base64 --decode)
```

## 4. 생성한 API Token을 k8s secret으로 생성
```
kubectl create secret generic apitoken --from-literal=apitoken=$API_TOKEN
```

## 5. CronJob 생성
| Environment | Description | Content | Required |
|:-|:-|:-|:-|
| API_TOKEN | secret으로 생성한 apitoken | key: apitoken /name: apitoken | Required |
| API_URL | Control Plane API IP | 127.0.0.1 | Required |
| KEY_NAME | secret으로 생성한 ssh key |	privatekey | Required |
|OS_USER | Node들에 접속할 OS계정 | user | 기본값 : root | |
| CRI_TYPE | 컨테이너 런타임 인터페이스 | docker/crictl | 기본값 : root | |
| CONTROL_PLANE | CONTROL PLANE 도 정리 | true/false | 기본값 : true | |
| PORT | k8s API PORT | 6443 | 기본값 : 6443 | |

## 6. Sample Cronjob Yaml
```
apiVersion: batch/v1
kind: CronJob
metadata:
  name: image-prune
spec:
  schedule: "0 0 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: image-prune
            image: pangyeons/image-prune:1.1
            imagePullPolicy: IfNotPresent
            command: # 아래 command 배열 수정 및 삭제 금지
            - /bin/sh
            - -c
            - chmod +x image_prune.sh; /image_prune.sh
            volumeMounts:
            - mountPath: /etc/sshkey # 수정 및 삭제 금지
              name: secret-sshkey
            env:
            - name: API_TOKEN # 수정 및 삭제 금지
              valueFrom:
                secretKeyRef:
                  key: apitoken # 위에 가이드대로 생성한 token
                  name: apitoken # 위에 가이드대로 생성한 token
            - name: API_URL # 수정 및 삭제 금지
              value: "172.1.1.1" # Control Plane API IP
            - name: KEY_NAME # 위에 가이드대로 생성한 SSH KEY Secret
              value: "privatekey"
            - name: CRI_TYPE # Container Runtime이 crictl일 경우
              value: "crictl"
            - name: CONTROL_PLANE # Control Plane에서는 동작안함.
              value: "false"
            - name: PORT
              value: "6443"
          restartPolicy: OnFailure
          volumes:
          - name: secret-sshkey
            secret:
              defaultMode: 0600 # 수정 및 삭제 금지
              secretName: sshkey # 위에 가이드대로 생성한 SSH KEY Secret
```
