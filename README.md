# 📊 Monitoring Stack: from Docker to Kubernetes

Пет-проєкт, у якому я поетапно розгортаю один і той самий моніторинг-стек
(**Prometheus + Grafana + Alertmanager + exporters**) на чотирьох різних платформах —
від локального Docker до Kubernetes у хмарі:

```
Docker (monolith) → Docker Compose → AWS ECS Fargate (CI/CD) → Kubernetes (Minikube + EKS/Helm/ArgoCD)
```

Ідея проєкту — не просто «підняти Grafana», а показати еволюцію одного й того самого
рішення: як змінюється підхід до контейнеризації, конфігурації, мережі, безпеки та
деплою в міру ускладнення інфраструктури. Об'єкт моніторингу скрізь той самий —
простий веб-сервіс на nginx, метрики якого видно в Grafana.

---

## Навіщо цей проєкт

Хотів на власному прикладі пройти шлях від «одного контейнера з усім усередині» до
повноцінного GitOps на Kubernetes, і закріпити на практиці:

- побудову Docker-образів, у тому числі роботу з multi-stage build та process supervisor;
- перехід від імперативного `docker run` до декларативного Docker Compose;
- побудову CI/CD-конвеєра (git push → build → tag → push → deploy) та Infrastructure as
  Code в AWS;
- проєктування мережі, IAM-ролей і секретів за принципом least privilege;
- основи Kubernetes і різницю між «руками» (Minikube) та production-подібним
  підходом (EKS + Helm + Argo CD).

## 🧱 Структура репозиторію

Один репозиторій, чотири теки — кожна відповідає окремому етапу еволюції:

```
lab-monitoring/
├── 01-docker-monolith/     # Dockerfile, конфіги
├── 02-docker-compose/      # compose.yaml, конфіги
├── 03-aws-ecs/             # Terraform/CFN, buildspec.yml, app/
├── 04-kubernetes/          # minikube/, eks/, helm/, argocd/
└── README.md
```

Кожна тека самодостатня і має власний README з поясненням, що саме зроблено і чому.

## ℹ Що таке цей моніторинг-стек

**Prometheus** — база даних часових рядів, яка періодично збирає (scrape) метрики із
сервісів. **Grafana** будує з цих метрик графіки й дашборди. **Alertmanager** отримує
спрацьовані алерти від Prometheus і вирішує, кому їх надіслати. **Exporters** —
невеликі агенти, що віддають метрики у форматі Prometheus (`node_exporter` — метрики
хоста, `cAdvisor` — метрики контейнерів).

---

## Рівень 1 — Моноліт у Docker

Один Docker-образ, всередині якого через `supervisord` одночасно працюють Prometheus,
Grafana, Alertmanager і два exporters. Поруч окремим sidecar-контейнером — nginx, який
цей стек моніторить.

Зроблено навмисно «неправильно» — щоб на практиці відчути, чому Docker-контейнер за
задумом розрахований на один процес (PID 1), і що потрібно, аби це обійти.

**Стек:** Prometheus `:9090` · Grafana `:3000` · Alertmanager `:9093` ·
node_exporter `:9100` · cAdvisor `:8080` · nginx `:80`

**Реалізовано:**
- multi-stage Dockerfile, що копіює готові бінарники з офіційних образів;
- `supervisord.conf` як «диригент» процесів;
- алерт `TargetDown`, що спрацьовує при падінні будь-якого таргета;
- робочий дашборд Grafana з метриками nginx.

```bash
docker build -t monitoring-monolith:dev .
docker network create monlab
docker run -d --name web --network monlab -p 8081:80 nginx:alpine
docker run -d --name mon --network monlab -p 3000:3000 -p 9090:9090 -p 9093:9093 monitoring-monolith:dev
```

**Cleanup:**
```bash
docker rm -f mon web web-exp
docker network rm monlab
docker rmi monitoring-monolith:dev
```

---

## Рівень 2 — Той самий стек на Docker Compose

Той самий набір сервісів, але розплутаний: кожен сервіс — окремий контейнер, усе
описано декларативно в одному `compose.yaml`. Дані Grafana та Prometheus зберігаються
між рестартами завдяки named volumes.

**Реалізовано:**
- `compose.yaml` з мережею й volumes для Prometheus/Grafana;
- секрети через `.env` (не комітяться в Git);
- конфіги монтуються тільки для читання (`:ro`).

```bash
echo "GRAFANA_PASS=changeme123" > .env
docker compose up -d
```

**Cleanup:**
```bash
docker compose down -v
```

---

## Рівень 3 — CI/CD + AWS ECS Fargate

Повноцінний конвеєр: `git push` → CI/CD збирає образ → тегує за `COMMIT_SHA` → пушить у
ECR → деплоїть у ECS Fargate. Інфраструктура описана як код. Веб-сервіс і моніторинг —
два окремих ECS-сервіси в одному кластері, що спілкуються через Service Connect / Cloud
Map.

**Архітектура:**
- VPC `10.0.0.0/16`, 2 availability zones;
- публічні сабнети — тільки ALB і NAT Gateway; ECS-задачі — у приватних сабнетах, без
  публічних IP;
- security groups за least privilege (задачі приймають трафік тільки від ALB);
- окремі IAM task execution role і task role;
- конфіги в Parameter Store, секрети в Secrets Manager;
- CloudWatch Log groups з retention (7 днів).

**Реалізовано:**
- Terraform/CloudFormation для VPC, ECS, ALB, ECR, IAM;
- CI/CD-пайплайн (CodePipeline + CodeBuild) з `buildspec.yml`;
- ★ вирішено питання персистентності даних моніторингу на Fargate (ephemeral storage
  vs EFS) — рішення й обґрунтування в `03-aws-ecs/README.md`.

**Definition of Done:** push у гілку автоматично оновлює образ у ECS; Grafana через ALB
показує метрики web, зібрані через internal DNS кластера.

💲 Найдорожчий ресурс тут — NAT Gateway, тому в конфігурації свідомо один NAT (або
VPC Endpoints замість нього) для економії.

**Cleanup:**
```bash
terraform destroy
```

---

## Рівень 4 — Kubernetes

Той самий стек, тепер у Kubernetes: спершу локально (Minikube), потім у хмарі (EKS) з
Helm і Argo CD.

### 4A — Minikube (локально)

Base-версія на «голих» маніфестах — Deployment + Service + ConfigMap + Secret для
кожного компонента стека в namespace `monitoring`.

```bash
minikube start --driver=docker --memory=4096 --cpus=2
kubectl apply -f 04-kubernetes/minikube/
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

Перевірено самовідновлення: видалення Pod-а через `kubectl delete pod` автоматично
призводить до підняття нового екземпляра Deployment-ом.

### 4B — EKS + Helm + Argo CD (GitOps)

- кластер EKS піднятий через `eksctl` на spot-нодах `t3.small` (мінімізація вартості);
- стек встановлено через Helm (`kube-prometheus-stack` + власний chart для web);
- Argo CD синхронізує стан кластера з Git — зміна в `values.yaml` після `git push`
  автоматично докочується без ручного `kubectl apply`.

```bash
eksctl create cluster --name lab-eks --nodes 1 --node-type t3.small --spot
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

**Cleanup:**
```bash
eksctl delete cluster --name lab-eks
```

> Після видалення кластера окремо перевіряю EC2 → Load Balancers: Service типу
> `LoadBalancer` створює AWS ELB, який eksctl не завжди прибирає автоматично.

---

## 🔒 Безпека — наскрізні практики

- секрети ніде не комітяться в Git (`.env`, Secrets Manager, K8s Secret);
- least privilege на всіх рівнях, де є IAM/RBAC;
- приватні сабнети для задач/подів там, де немає прямої потреби в публічному доступі;
- non-root контейнери й resource limits на Kubernetes;
- на EKS — IRSA замість довгоживучих AWS-ключів у подах.

## 💲 Контроль вартості

Рівні 1, 2 і 4A — повністю безкоштовні (локально). Рівні 3 і 4B використовують AWS і
тарифікуються погодинно (NAT Gateway, ALB, EKS control plane, EFS) — тому для них
увімкнений AWS Budgets з лімітом і алертом, а ресурси видаляються одразу після
демонстрації.

## 🧹 Cleanup

| Рівень | Команда |
|---|---|
| 1 | `docker rm -f ... && docker rmi ...` |
| 2 | `docker compose down -v` |
| 3 | `terraform destroy` |
| 4A | `minikube delete` |
| 4B | `eksctl delete cluster` |

---

## Стек технологій

`Docker` · `Docker Compose` · `Prometheus` · `Grafana` · `Alertmanager` ·
`Terraform` / `CloudFormation` · `AWS ECS Fargate` · `AWS ECR` · `AWS CodePipeline /
CodeBuild` · `Kubernetes` · `Minikube` · `AWS EKS` · `Helm` · `Argo CD`

---

*Один репозиторій, чотири рівні — від `docker run` до GitOps на Kubernetes.*