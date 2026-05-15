# Kubernetes CI/CD 集成详解

基于项目描述中的"使用 Helm 实现持续集成与持续交付（CI/CD）"，以下是 CI/CD 集成的详细知识：

## 一、CI/CD 基础概念

### 1.1 核心流程
```
代码提交 → 持续集成 → 持续交付 → 持续部署
    ↓          ↓          ↓          ↓
  开发      构建测试    预发布验证   生产部署
```

### 1.2 GitOps 模式
```
Git 仓库 (唯一真相源) → CI 流水线 → CD 工具 → Kubernetes 集群
     ↓                    ↓           ↓           ↓
 配置即代码          自动化构建     状态同步     实际状态
```

## 二、CI/CD 工具链

### 2.1 常见工具组合
- **CI 工具**：Jenkins、GitLab CI、GitHub Actions、CircleCI
- **CD 工具**：ArgoCD、Flux、Spinnaker、Tekton
- **镜像仓库**：Docker Hub、Harbor、ECR、GCR
- **配置管理**：Helm、Kustomize、Jsonnet

### 2.2 工具选择矩阵
| 工具 | 类型 | 特点 | 适用场景 |
|------|------|------|---------|
| **Jenkins** | CI/CD | 插件丰富、灵活 | 复杂流水线、企业级 |
| **GitLab CI** | CI/CD | 一体化、简单 | GitLab 用户、中小项目 |
| **GitHub Actions** | CI/CD | 云原生、集成好 | GitHub 用户、开源项目 |
| **ArgoCD** | CD | GitOps、声明式 | Kubernetes 原生、GitOps |
| **Flux** | CD | GitOps、轻量 | 简单 GitOps、资源少 |
| **Tekton** | CI/CD | 云原生、可扩展 | 复杂流水线、K8s 原生 |

## 三、Jenkins 集成

### 3.1 Jenkins 部署
```yaml
# jenkins.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 50000
          name: agent
        env:
        - name: JAVA_OPTS
          value: "-Djenkins.install.runSetupWizard=false"
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        - name: docker-sock
          mountPath: /var/run/docker.sock
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1"
      volumes:
      - name: jenkins-home
        persistentVolumeClaim:
          claimName: jenkins-pvc
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
  selector:
    app: jenkins
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 3.2 Jenkinsfile 示例
```groovy
pipeline {
    agent {
        kubernetes {
            label 'jenkins-agent'
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:4.10-3
    args: ['\$(JENKINS_SECRET)', '\$(JENKINS_NAME)']
  - name: docker
    image: docker:20.10
    command: ['cat']
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:1.22
    command: ['cat']
    tty: true
  - name: helm
    image: alpine/helm:3.7
    command: ['cat']
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    
    environment {
        DOCKER_REGISTRY = 'registry.example.com'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/myapp"
        HELM_CHART = './charts/myapp'
        KUBE_NAMESPACE = 'production'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                container('docker') {
                    sh '''
                        docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                        docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }
        
        stage('Test') {
            steps {
                container('docker') {
                    sh 'docker run --rm ${DOCKER_IMAGE}:${BUILD_NUMBER} npm test'
                }
            }
        }
        
        stage('Push') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(
                        credentialsId: 'docker-registry',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh '''
                            docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} ${DOCKER_REGISTRY}
                            docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                            docker push ${DOCKER_IMAGE}:latest
                        '''
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                container('helm') {
                    withCredentials([file(
                        credentialsId: 'kubeconfig',
                        variable: 'KUBECONFIG'
                    )]) {
                        sh '''
                            export KUBECONFIG=${KUBECONFIG}
                            helm upgrade --install myapp ${HELM_CHART} \
                                --namespace ${KUBE_NAMESPACE} \
                                --set image.tag=${BUILD_NUMBER} \
                                --set image.repository=${DOCKER_IMAGE} \
                                --wait
                        '''
                    }
                }
            }
        }
        
        stage('Verify') {
            steps {
                container('kubectl') {
                    withCredentials([file(
                        credentialsId: 'kubeconfig',
                        variable: 'KUBECONFIG'
                    )]) {
                        sh '''
                            export KUBECONFIG=${KUBECONFIG}
                            kubectl rollout status deployment/myapp -n ${KUBE_NAMESPACE} --timeout=300s
                            kubectl get pods -n ${KUBE_NAMESPACE} -l app=myapp
                        '''
                    }
                }
            }
        }
    }
    
    post {
        success {
            emailext (
                subject: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: "Build successful\n\n${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
        failure {
            emailext (
                subject: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: "Build failed\n\n${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
    }
}
```

## 四、GitLab CI 集成

### 4.1 .gitlab-ci.yml 配置
```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - scan
  - deploy

variables:
  DOCKER_IMAGE: registry.example.com/myapp
  HELM_CHART: ./charts/myapp
  KUBE_NAMESPACE: production

# 镜像构建
build:
  stage: build
  image: docker:20.10
  services:
    - docker:20.10-dind
  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
  script:
    - docker build -t $DOCKER_IMAGE:$CI_COMMIT_SHA .
    - docker tag $DOCKER_IMAGE:$CI_COMMIT_SHA $DOCKER_IMAGE:latest
  only:
    - main
    - develop

# 单元测试
test:
  stage: test
  image: node:16
  script:
    - npm install
    - npm test
  artifacts:
    reports:
      junit: test-results.xml

# 安全扫描
scan:
  stage: scan
  image: aquasec/trivy:0.18.3
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $DOCKER_IMAGE:$CI_COMMIT_SHA
  allow_failure: true

# 部署到开发环境
deploy-dev:
  stage: deploy
  image: alpine/helm:3.7
  script:
    - apk add --no-cache git
    - helm upgrade --install myapp-dev $HELM_CHART
      --namespace development
      --set image.tag=$CI_COMMIT_SHA
      --set image.repository=$DOCKER_IMAGE
      --wait
  environment:
    name: development
    url: https://dev.example.com
  only:
    - develop

# 部署到生产环境
deploy-prod:
  stage: deploy
  image: alpine/helm:3.7
  script:
    - apk add --no-cache git
    - helm upgrade --install myapp $HELM_CHART
      --namespace $KUBE_NAMESPACE
      --set image.tag=$CI_COMMIT_SHA
      --set image.repository=$DOCKER_IMAGE
      --wait
  environment:
    name: production
    url: https://example.com
  only:
    - main
  when: manual
```

### 4.2 GitLab Runner 配置
```yaml
# gitlab-runner.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab-runner
  namespace: gitlab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: gitlab-runner
  template:
    metadata:
      labels:
        app: gitlab-runner
    spec:
      serviceAccountName: gitlab-runner
      containers:
      - name: gitlab-runner
        image: gitlab/gitlab-runner:alpine-v14.7.0
        env:
        - name: CI_SERVER_URL
          value: "https://gitlab.example.com"
        - name: REGISTRATION_TOKEN
          valueFrom:
            secretKeyRef:
              name: gitlab-runner-secret
              key: registration-token
        - name: KUBERNETES_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: KUBERNETES_SERVICE_ACCOUNT
          value: gitlab-runner
        volumeMounts:
        - name: config
          mountPath: /etc/gitlab-runner
        - name: docker-sock
          mountPath: /var/run/docker.sock
      volumes:
      - name: config
        emptyDir: {}
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: gitlab
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gitlab-runner
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec", "pods/log"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gitlab-runner
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gitlab-runner
subjects:
- kind: ServiceAccount
  name: gitlab-runner
  namespace: gitlab
```

## 五、ArgoCD GitOps

### 5.1 ArgoCD 部署
```yaml
# argocd.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/helm-charts.git
    targetRevision: HEAD
    path: charts/myapp
    helm:
      valueFiles:
        - values-production.yaml
      parameters:
        - name: replicaCount
          value: "3"
        - name: image.tag
          value: "v1.0.0"
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 5.2 ApplicationSet 自动发现
```yaml
# applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/myorg/environments.git
      revision: HEAD
      directories:
        - path: "*/overlays/*"
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/helm-charts.git
        targetRevision: HEAD
        path: charts/myapp
        helm:
          valueFiles:
            - '{{path}}/values.yaml'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### 5.3 多环境配置
```
environments/
├── base/
│   └── values.yaml          # 基础配置
├── development/
│   └── overlays/
│       └── dev/
│           └── values.yaml  # 开发环境配置
├── staging/
│   └── overlays/
│       └── staging/
│           └── values.yaml  # 预发布环境配置
└── production/
    └── overlays/
        └── prod/
            └── values.yaml  # 生产环境配置
```

## 六、Tekton 云原生流水线

### 6.1 Tekton 部署
```yaml
# tekton-pipeline.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: build-deploy-pipeline
spec:
  params:
  - name: git-url
    type: string
  - name: git-revision
    type: string
    default: "main"
  - name: image
    type: string
  
  workspaces:
  - name: source
  - name: docker-config
  - name: kubeconfig
  
  tasks:
  - name: fetch-source
    taskRef:
      name: git-clone
    workspaces:
    - name: output
      workspace: source
    params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.git-revision)
  
  - name: build-image
    runAfter: ["fetch-source"]
    taskRef:
      name: buildah
    workspaces:
    - name: source
      workspace: source
    - name: dockerconfig
      workspace: docker-config
    params:
    - name: IMAGE
      value: $(params.image)
    - name: DOCKERFILE
      value: "./Dockerfile"
  
  - name: deploy
    runAfter: ["build-image"]
    taskRef:
      name: helm-deploy
    workspaces:
    - name: source
      workspace: source
    - name: kubeconfig
      workspace: kubeconfig
    params:
    - name: chart
      value: "./charts/myapp"
    - name: namespace
      value: "production"
    - name: image
      value: $(params.image)
```

### 6.2 Tekton Trigger
```yaml
# tekton-trigger.yaml
apiVersion: triggers.tekton.dev/v1alpha1
kind: EventListener
metadata:
  name: github-listener
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
  - name: github-push-trigger
    interceptors:
    - ref:
        name: "github"
      params:
      - name: "secretRef"
        value:
          secretName: github-secret
          secretKey: token
      - name: "eventTypes"
        value: ["push"]
    bindings:
    - ref: github-binding
    template:
      ref: pipeline-template
---
apiVersion: triggers.tekton.dev/v1alpha1
kind: TriggerBinding
metadata:
  name: github-binding
spec:
  params:
  - name: git-url
    value: $(body.repository.clone_url)
  - name: git-revision
    value: $(body.after)
  - name: image
    value: registry.example.com/myapp:$(body.after)
```

## 七、安全与合规

### 7.1 镜像安全扫描
```yaml
# trivy-scan.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: trivy-scan
  namespace: security
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: trivy
            image: aquasec/trivy:0.18.3
            args:
            - image
            - --exit-code
            - "1"
            - --severity
            - "HIGH,CRITICAL"
            - --format
            - "json"
            - registry.example.com/myapp:latest
            volumeMounts:
            - name: reports
              mountPath: /reports
          restartPolicy: Never
          volumes:
          - name: reports
            persistentVolumeClaim:
              claimName: scan-reports-pvc
```

### 7.2 策略检查
```yaml
# kyverno-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: enforce
  rules:
  - name: check-for-labels
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "All pods must have app and version labels"
      pattern:
        metadata:
          labels:
            app: "?*"
            version: "?*"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: enforce
  rules:
  - name: validate-image-tag
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Using latest tag is not allowed"
      pattern:
        spec:
          containers:
          - image: "!*:latest"
```

### 7.3 密钥管理
```yaml
# external-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secret
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: database/creds
      property: username
  - secretKey: password
    remoteRef:
      key: database/creds
      property: password
```

## 八、监控与可观测性

### 8.1 流水线监控
```yaml
# prometheus-rule.yaml
groups:
- name: ci-cd-alerts
  rules:
  - alert: PipelineFailureRateHigh
    expr: rate(tekton_pipelinerun_duration_seconds_count{status="failed"}[5m]) / rate(tekton_pipelinerun_duration_seconds_count[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High pipeline failure rate"
      description: "Pipeline failure rate is {{ $value }}%"
  
  - alert: DeploymentDurationHigh
    expr: histogram_quantile(0.95, sum(rate(argocd_app_reconcile_duration_seconds_bucket[5m])) by (le, name)) > 300
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Deployment taking too long"
      description: "Deployment {{ $labels.name }} is taking {{ $value }} seconds"
```

### 8.2 仪表盘配置
```json
{
  "dashboard": {
    "title": "CI/CD Pipeline Monitoring",
    "panels": [
      {
        "title": "Pipeline Success Rate",
        "targets": [{
          "expr": "sum(rate(tekton_pipelinerun_duration_seconds_count{status=\"succeeded\"}[5m])) / sum(rate(tekton_pipelinerun_duration_seconds_count[5m]))",
          "legendFormat": "Success Rate"
        }]
      },
      {
        "title": "Deployment Frequency",
        "targets": [{
          "expr": "rate(argocd_app_reconcile_count[1h])",
          "legendFormat": "{{name}}"
        }]
      }
    ]
  }
}
```

## 九、最佳实践

### 9.1 流水线设计原则
1. **快速反馈**：快速失败，快速修复
2. **可重复性**：相同输入产生相同输出
3. **安全性**：最小权限，密钥管理
4. **可观测性**：完整的日志和监控
5. **可维护性**：模块化，可重用

### 9.2 环境策略
```yaml
# 环境隔离策略
development:
  autoDeploy: true
  manualApproval: false
  replicas: 1
  resources: small

staging:
  autoDeploy: true
  manualApproval: true
  replicas: 2
  resources: medium
  smokeTests: required

production:
  autoDeploy: false
  manualApproval: true
  replicas: 3
  resources: large
  canaryDeployment: enabled
  rollbackWindow: 30m
```

### 9.3 回滚策略
```yaml
# 自动回滚配置
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    retry:
      limit: 2
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  healthChecks:
  - type: Rollout
    name: myapp
    value: ">=95%"
```

## 十、故障排查

### 10.1 常见问题
```bash
# Jenkins 代理连接问题
kubectl logs -n jenkins jenkins-0
kubectl describe pod -n jenkins jenkins-agent-xxxx

# GitLab Runner 注册问题
kubectl logs -n gitlab gitlab-runner-xxxx
kubectl describe configmap -n gitlab gitlab-runner-config

# ArgoCD 同步失败
argocd app get myapp
argocd app sync myapp
argocd app history myapp

# Tekton 流水线失败
kubectl get pipelinerun -n tekton-pipelines
kubectl describe pipelinerun <name> -n tekton-pipelines
kubectl logs -n tekton-pipelines <taskrun-pod>
```

### 10.2 调试命令
```bash
# 检查流水线状态
kubectl get pods -n <namespace> -l tekton.dev/taskRun
kubectl get pipelinerun -n <namespace>

# 检查部署状态
kubectl get deployments -n <namespace>
kubectl describe deployment <name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 检查镜像拉取
kubectl describe pod <pod-name> -n <namespace> | grep -A5 -B5 "ImagePull"

# 检查网络连接
kubectl exec -it <pod-name> -n <namespace> -- curl <service-url>
```

### 10.3 性能优化
1. **缓存策略**：构建缓存，依赖缓存
2. **并行执行**：并行运行独立任务
3. **资源优化**：合理分配 CPU/内存
4. **镜像优化**：使用多阶段构建，减小镜像大小
5. **网络优化**：使用本地镜像仓库

---

**关键要点**：Kubernetes CI/CD 需要结合合适的工具链，实现从代码到生产的全流程自动化。GitOps 模式将配置存储在 Git 中，确保环境一致性和可追溯性。