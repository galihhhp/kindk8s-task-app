## Project Overview – Observability Stack

Folder `obervability/` ini berfokus ke observability full stack untuk memonitor aplikasi di `app/`:

- Prometheus (metrics collection)
- Grafana (dashboards)
- Loki + Promtail (logs)
- kube-state-metrics, node-exporter (cluster metrics)

**Prerequisites:**

- Cluster sudah dibuat dan aplikasi sudah running di namespace `development` (lihat `app/README.md`)
- Namespace `development` dengan pods backend, frontend, dan PostgreSQL sudah ada

**Kontrak dengan Aplikasi:**
Observability stack mengasumsikan aplikasi di namespace `development` dengan:

- Labels: `app=backend|frontend|postgres`, `tier=api|ui|database`
- Service names: `backend-service`, `frontend-service`, `postgres-service`
- Logs dicetak ke stdout/stderr

[Inference] File manifests untuk stack observability belum dibuat di repo ini; dokumen ini bertindak sebagai blueprint yang bisa kamu implementasikan secara bertahap.

---

## Phase 1: Metrics Stack (Prometheus + kube-state-metrics + node-exporter)

Target phase ini: bisa mengumpulkan metrics dari cluster dan aplikasi.
Semua dikelola sebagai manifests YAML dan diorganisasi dengan Kustomize.

### Task 1.0: Observability Base Structure

**Files:**

- `obervability/base/kustomization.yaml`
- `obervability/base/namespace.yaml`

**Requirements:**

- Namespace: `observability`
- Kustomization base mereferensikan semua komponen observability (akan ditambah di task berikut)

**Learning:**

- ✅ Observability namespace
- ✅ Kustomize untuk stack observability

---

### Task 1.1: Prometheus + kube-state-metrics + node-exporter

**Files:**

- `obervability/base/prometheus/`
- `obervability/base/kube-state-metrics/`
- `obervability/base/node-exporter/`

**Requirements:**

- Tambahkan:
  - Prometheus Deployment/StatefulSet + Service
  - kube-state-metrics Deployment + Service
  - node-exporter DaemonSet + Service
- Konfigurasi Prometheus scrape:
  - Cluster metrics (node, pod, service)
  - Kube-state-metrics
  - node-exporter
- Semua file direferensikan oleh `obervability/base/kustomization.yaml`

**Learning:**

- ✅ Prometheus deployment pattern
- ✅ Cluster metrics scraping
- ✅ Kube-state-metrics usage
- ✅ Node-level metrics via node-exporter

---

### Task 1.2: Overlays for Dev Observability

**Files:**

- `obervability/env/dev/kustomization.yaml`

**Requirements:**

- Overlay dev:
  - Set namespace: `observability`
  - Opsional: patch resource requests/limits agar pas untuk cluster lokal
- Deploy:
  - `kubectl apply -k obervability/env/dev`
- Verifikasi:
  - `kubectl get pods -n observability`
  - `kubectl get svc -n observability`

**Learning:**

- ✅ Kustomize overlays untuk observability
- ✅ Deployment observability stack ke dev

---

## Phase 2: Logs Stack (Loki + Promtail)

Target: mengumpulkan logs dari semua pod, termasuk aplikasi sendiri.

### Task 2.0: Loki Deployment

**Files:**

- `obervability/base/loki/`

**Requirements:**

- Deploy Loki sebagai log store:
  - StatefulSet/Deployment
  - Service ClusterIP
- Konfigurasi storage:
  - Untuk lokal boleh pakai storage sederhana (emptyDir atau hostPath)

**Learning:**

- ✅ Loki deployment basics
- ✅ Log storage pattern

---

### Task 2.1: Promtail DaemonSet

**Files:**

- `obervability/base/promtail/`

**Requirements:**

- Deploy Promtail sebagai DaemonSet di semua node
- Konfigurasi Promtail:
  - Tail logs dari `/var/log/containers`
  - Kirim ke Loki dengan label:
    - namespace
    - pod
    - container
    - app
- Tambahkan semua resource ke `obervability/base/kustomization.yaml`

**Learning:**

- ✅ Promtail DaemonSet
- ✅ Container log scraping
- ✅ Labeling logs untuk query di Loki

---

### Task 2.2: Verify Logs Flow

**Checklist:**

- [ ] Pods Loki dan Promtail running: `kubectl get pods -n observability`
- [ ] Generate logs di backend:
  - Hit endpoint `/api/hello` beberapa kali
  - `kubectl logs` untuk verifikasi
- [ ] Verifikasi logs muncul di Loki (nanti via Grafana di phase berikut)

**Learning:**

- ✅ End-to-end log pipeline
- ✅ Debugging logs di cluster

---

## Phase 3: Grafana Dashboards

Target: punya satu UI pusat untuk melihat metrics dan logs.

### Task 3.0: Grafana Deployment

**Files:**

- `obervability/base/grafana/`

**Requirements:**

- Deploy Grafana Deployment + Service
- Expose Grafana:
  - Opsi A: NodePort (misal 32000)
  - Opsi B: Ingress (kalau sudah ada Ingress controller)
- Tambahkan ke `obervability/base/kustomization.yaml`

**Learning:**

- ✅ Grafana deployment
- ✅ External access patterns (NodePort atau Ingress)

---

### Task 3.1: Connect Prometheus and Loki as Data Sources

**Steps:**

- Masuk ke Grafana (pakai NodePort atau port-forward)
- Tambahkan Prometheus sebagai data source:
  - URL: Service Prometheus (ClusterIP atau via port-forward)
- Tambahkan Loki sebagai data source:
  - URL: Service Loki

**Learning:**

- ✅ Grafana data source configuration
- ✅ Integrasi metrics dan logs

---

### Task 3.2: Dashboards untuk Cluster dan Aplikasi

**Tasks:**

- Import dashboard siap pakai untuk:
  - Kubernetes cluster
  - Node metrics
- Buat dashboard custom:
  - Panel metrics backend (request count, error count, latency bila ada)
  - Panel logs (Loki Explore atau panel logs di dashboard)

**Learning:**

- ✅ Dashboard creation
- ✅ Metrics visualization
- ✅ Logs exploration

---

## Phase 4: Validation & Failure Scenarios

### Task 4.1: Simulate Failures

**Scenarios:**

- Scale down backend ke 0 replicas dan lihat efeknya di metrics (Prometheus)
- Paksa pod crash (image salah atau env salah) dan lihat error di logs (Loki)
- Observasi di Grafana:
  - Perubahan metrics (pod availability)
  - Logs error (stack traces)

**Learning:**

- ✅ Practical troubleshooting dengan metrics + logs
- ✅ Observability-driven debugging

---

## Phase 5: Testing, Validation, and Cleanup

### Task 5.1: Manual Testing Checklist

**Test Scenarios:**

- [ ] Cluster running: `kubectl get nodes`
- [ ] Namespace `development` dan `observability` ada
- [ ] Pods aplikasi running di namespace `development`
- [ ] Pods observability stack running di namespace `observability`
- [ ] Prometheus UI bisa diakses (via port-forward atau Service)
- [ ] Grafana UI bisa diakses
- [ ] Data source Prometheus dan Loki healthy di Grafana
- [ ] Dashboard cluster menunjukkan metrics
- [ ] Logs backend terlihat di Grafana (Loki)

**Learning:**

- ✅ End-to-end verification
- ✅ Manual testing procedures

---

### Task 5.2: Cleanup & Reproducibility

**Commands:**

```bash
kubectl delete namespace observability
```

**Learning:**

- ✅ Idempotent workflows
- ✅ Clean teardown
- ✅ Confidence untuk rebuild dari nol

---

## Project Structure (Suggested)

```text
obervability/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── prometheus/
│   ├── kube-state-metrics/
│   ├── node-exporter/
│   ├── loki/
│   ├── promtail/
│   └── grafana/
└── env/
    └── dev/
        └── kustomization.yaml
```

---

## Expected Deliverables

### 1. Infrastructure yang Running

- ✅ Namespace `observability` untuk observability stack
- ✅ Observability stack lengkap running di `observability`:
  - Prometheus
  - kube-state-metrics
  - node-exporter
  - Loki
  - Promtail
  - Grafana

### 2. Akses ke Sistem

- ✅ Backend API accessible via Service (NodePort atau Ingress)
- ✅ Grafana accessible via browser
- ✅ Prometheus UI accessible
- ✅ Logs bisa di-query via Grafana (Loki)

### 3. Skills yang Dikuasai

- ✅ Deploy observability stack full dengan manifests yang diorganisasi via Kustomize
- ✅ Baca dan pahami metrics cluster dan aplikasi
- ✅ Baca dan filter logs via Loki di Grafana
- ✅ Debug issue aplikasi menggunakan kombinasi metrics + logs

### 4. Next Steps

- ✅ Tambah HPA (Horizontal Pod Autoscaler) menggunakan metrics Prometheus
- ✅ Tambah Ingress + TLS untuk akses Grafana dan aplikasi
- ✅ Tambah Alertmanager untuk integrasi alert ke channel eksternal (email, Slack)
- ✅ Refactor observability manifests menjadi reusable modules untuk project lain
