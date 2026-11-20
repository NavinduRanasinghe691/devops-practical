# DevOps Practical: Flask → CI → Docker → Kubernetes → Render

A hands-on pipeline: one tiny Flask app taken through version control, automated
testing, containerization, orchestration, and automatic deployment to the web.

```
devops-practical/
├── app.py                         Flask app (reads $PORT, defaults to 5000)
├── test_app.py                    pytest "quality gate"
├── requirements.txt               flask==3.0.0, pytest==7.4.0
├── Dockerfile                     python:3.12-slim image, non-root user
├── .dockerignore / .gitignore
├── .github/workflows/ci.yml       CI: test, then verify the Docker image builds
├── k8s/
│   ├── deployment.yaml            2 replicas + readiness/liveness probes
│   └── service.yaml               NodePort 80 → 5000
└── extras/docker-publish.yml.example   optional: auto-push image to Docker Hub
```

**You need:** Git, Python 3.12+, Docker Desktop, `kubectl`, `minikube`, and free
accounts on GitHub, Docker Hub and Render.

> Run every command from the **project root** (`devops-practical/`). Do **not**
> `cd k8s`; that is the classic reason a later `git add app.py` fails.

---

## Phase 1: Local dev and source control

```bash
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
pytest                            # 1 passed
python app.py                     # http://localhost:5000
```

Create an **empty** public repo on GitHub named `devops-practical`
(no README, no .gitignore, no licence), then:

```bash
git init
git add .
git commit -m "Initial commit: App and tests"
git branch -M main
git remote add origin https://github.com/<YOUR-USERNAME>/devops-practical.git
git push -u origin main
```

The repo name in the URL must match the one you created.
GitHub no longer accepts account passwords over HTTPS: authenticate with a
Personal Access Token, `gh auth login`, or Git Credential Manager.

## Phase 2: Continuous Integration

`.github/workflows/ci.yml` is already in the repo. The push above triggers it.
Open the repo's **Actions** tab: you should see two green jobs, `build-and-test` and `docker-build`.

## Phase 3: Containerization

```bash
docker build -t flask-app:v1 .
docker run --rm -p 8080:5000 flask-app:v1     # open http://localhost:8080
```

Host port 8080 is used on purpose: macOS (Monterey+) AirPlay Receiver occupies
port 5000. Stop with `Ctrl+C`.

Push to Docker Hub:

```bash
docker login
docker tag flask-app:v1 <YOUR-DOCKERHUB-USERNAME>/flask-app:v1
docker push <YOUR-DOCKERHUB-USERNAME>/flask-app:v1
```

## Phase 4: Orchestration (Kubernetes / Minikube)

```bash
kubectl version --client
minikube version
minikube start --driver=docker        # two plain hyphens, not an en-dash
```

Edit `k8s/deployment.yaml` and replace `<YOUR-DOCKERHUB-USERNAME>`. Then:

```bash
kubectl apply -f k8s/
kubectl get pods -w                   # wait for 2/2 Running and Ready
minikube service flask-service        # opens the app in your browser
```

Notes
- `kubectl` should be within one minor version of the cluster. If `kubectl version`
  warns about skew, use `minikube kubectl -- get pods` or install a current kubectl.
- No Docker Hub? Run `minikube image load flask-app:v1`, set the manifest image to
  `flask-app:v1`, and apply. Kubernetes will use the locally loaded image.

## Phase 5: Chaos test

```bash
kubectl get pods
kubectl delete pod <POD-NAME>
kubectl get pods -w                   # a replacement appears at once; the app stays up
```

The Deployment's desired state is `replicas: 2`, so Kubernetes recreates what you delete.

## Phase 6: Continuous Deployment on Render

The `$PORT` handling Render needs is already in `app.py`.

1. Sign in at render.com with GitHub → **New +** → **Web Service** → *Build and deploy from a Git repository* → pick `devops-practical`.
2. Branch `main`, Runtime **Docker**, Instance type **Free** → **Create Web Service**.
3. **Important:** open the service's **Settings → Auto-Deploy** and choose **After CI Checks Pass**.
   Render's default (*On Commit*) deploys every push without looking at your tests,
   so a red CI run would still go live.
4. Watch the build log run your Dockerfile, wait for the green **Live** badge, then open the URL.
   (Free instances sleep when idle; the first load can take about a minute.)

### The "no-touch" deployment test

A change to the message needs a matching change to the test, otherwise CI fails (as it should):

`app.py`
```python
    return "CI/CD and Docker Pipeline is a massive success! V2"
```

`test_app.py`
```python
    assert b"CI/CD and Docker Pipeline is a massive success! V2" in response.data
```

```bash
git add app.py test_app.py
git commit -m "Testing full automated deployment"
git push
```

Actions goes green → Render deploys → refresh the live URL.

**Bonus experiment:** first change *only* `app.py` and push. CI turns red and, with
*After CI Checks Pass* enabled, Render skips the deploy. Fix the test, push again, and it ships.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `git push` asks for a password and fails | Use a Personal Access Token or `gh auth login` |
| `remote: Repository not found` | Repo name or username in the remote URL doesn't match GitHub |
| `Address already in use` on 5000 (macOS) | AirPlay Receiver; use `-p 8080:5000` or switch it off in System Settings |
| `ImagePullBackOff` | Wrong Docker Hub username in `deployment.yaml`, image not pushed, or repo is private |
| `minikube start` fails on `–driver` | Smart-quote dash from copy-paste; retype as `--driver=docker` |
| `git add app.py` → `pathspec did not match` | You are still inside `k8s/`; `cd ..` |
| Render says deploy skipped | A CI check failed (or none ran) while Auto-Deploy is *After CI Checks Pass* |

## Changes from the original handout

| Change | Why |
|---|---|
| Phase 6 test edit added | The handout's V2 message fails the V1 test, so CI went red |
| Repo name `devops-practical` everywhere | Handout created `devops-practical` but pushed to `devops-masterclass` |
| Render Auto-Deploy → *After CI Checks Pass* | Default ignores CI, which contradicts "safely test, build, deploy" |
| Python 3.9 → 3.12 (Docker + CI) | 3.9 reached end-of-life in Oct 2025 |
| `actions/checkout@v4`, `setup-python@v4` → `@v7` | Current majors |
| Added `.gitignore`, `.dockerignore` | Stops `__pycache__`, `.git`, etc. entering Git and the image |
| `k8s/` committed to the repo | "Everything as code": the handout never committed it |
| `docker-build` CI job, `pull_request` trigger | Catch Dockerfile errors in CI, not on Render |
| Probes in `deployment.yaml`, non-root user in Dockerfile | Realistic self-healing and basic hardening |
| `--driver` typed with ASCII hyphens, `-p 8080:5000` | Copy-paste and macOS port-5000 fixes |

## Next steps (not included)

- Replace `python app.py` (Flask dev server) with **gunicorn** for production.
- Enable `extras/docker-publish.yml.example` so CI publishes the image, then have Kubernetes pull that tag.
- Add a `/health` endpoint and point the probes at it.
"# devops-practical" 
