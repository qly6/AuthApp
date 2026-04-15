# 🔐 SimpleAuth – MFA Authentication System (TOTP)

Hệ thống xác thực người dùng hiện đại với **JWT + Multi-Factor Authentication (MFA)** sử dụng TOTP, triển khai theo kiến trúc Cloud Native trên AWS EKS.

A modern authentication system with **JWT + Multi-Factor Authentication (MFA)** using TOTP, deployed with a cloud-native architecture on AWS EKS.

---

## 📦 Tech Stack | Công nghệ sử dụng

| Component          | Technology                                                      |
| ------------------ | --------------------------------------------------------------- |
| Backend API        | ASP.NET Core 8, Entity Framework Core, PostgreSQL, JWT, Otp.NET |
| Frontend UI        | Angular 17+, Bootstrap 5, angularx-qrcode                       |
| Database           | PostgreSQL (Bitnami / Amazon RDS optional)                      |
| Container Registry | Amazon ECR                                                      |
| Infrastructure     | Terraform (EKS, VPC, IAM, RDS)                                  |
| Deployment         | Helm Umbrella Chart                                             |
| CI/CD              | GitHub Actions + OIDC                                           |
| Automation Scripts | Bash                                                            |

---

## 📁 Project Structure | Cấu trúc dự án

```text
AuthApp/
├── backend/SimpleAuthApi/
├── frontend/SimpleAuthUi/
├── infrastructure/
│   ├── terraform/eks/
│   └── helm/simpleauth-chart/
├── scripts/
├── .github/workflows/deploy.yml
├── docker-compose.yml
└── README.md
```

---

## 🛠️ Requirements | Yêu cầu hệ thống

| Tool      | Version |
| --------- | ------- |
| Docker    | 24+     |
| AWS CLI   | v2      |
| Terraform | 1.5+    |
| kubectl   | 1.28+   |
| Helm      | 3.12+   |
| .NET SDK  | 8.0     |
| Node.js   | 20+     |

> ⚠️ Windows: Use Git Bash or WSL2 for running scripts.

---

## 🚀 Quick Start (Local) | Chạy local nhanh

### 1. Clone repo

```bash
git clone https://github.com/qly6/AuthApp.git
cd AuthApp
```

### 2. Create `.env` file | Tạo file `.env`

```env
DB_PASSWORD=StrongDBPassword123
JWT_SECRET=your-strong-secret-key-at-least-32-characters-long
```

### 3. Run app | Chạy ứng dụng

```bash
docker-compose up -d
```

### 4. Access | Truy cập

* Frontend: http://localhost:4200
* Backend: http://localhost:5000/swagger

### 5. Stop | Dừng

```bash
docker-compose down
```

---

## ☁️ Deploy to AWS EKS | Triển khai lên AWS

### 1. Configure AWS

```bash
aws configure
```

### 2. Optional env variables | Biến môi trường (tuỳ chọn)

```bash
export AWS_REGION="ap-southeast-1"
export EKS_CLUSTER="your-cluster-name"
export GITHUB_REPO="your-repo"
```

### 3. Run setup script

```bash
cd scripts
chmod +x *.sh
./setup-all.sh
```

### Script will | Script sẽ:

* Create EKS & VPC via Terraform
* Create ECR repositories
* Build & push Docker images
* Install AWS Load Balancer Controller
* Deploy with Helm
* Configure Ingress (ALB)

👉 Options:

```bash
./setup-all.sh --skip-terraform
./setup-all.sh --skip-build
```

---

## 🔍 Check deployment | Kiểm tra trạng thái

```bash
kubectl -n simpleauth get pods
kubectl -n simpleauth get ingress
```

---

## 🗑️ Destroy resources | Xoá tài nguyên

```bash
./destroy-all.sh --force
```

---

## 🔧 CI/CD (GitHub Actions)

### 1. Setup OIDC

```bash
export GITHUB_REPO="your-repo"
./scripts/setup-gh-oidc.sh
```

### 2. Add GitHub Secrets

* `DB_PASSWORD`
* `JWT_SECRET`

### 3. Deploy

Push to `main` → auto build & deploy.

---

## 🔐 MFA Flow | Luồng MFA

### Enable MFA | Kích hoạt MFA

1. Login
2. Go to Profile
3. Enable MFA
4. Scan QR (Google Authenticator/Authy)
5. Enter OTP

### Login Flow | Luồng đăng nhập

* Enter username/password
* If MFA enabled → enter OTP
* Receive JWT

---

## 🐛 Troubleshooting

| Issue              | Cause              | Fix                |
| ------------------ | ------------------ | ------------------ |
| ImagePullBackOff   | Image not pushed   | Rebuild & push     |
| UI CrashLoop       | Wrong config       | Fix ConfigMap      |
| API DB error       | DB not ready       | Restart deployment |
| Helm timeout       | Pods not ready     | Increase timeout   |
| ALB not accessible | Subnet tag missing | Fix tags           |

---

## 🤝 Contributing

Contributions are welcome!
Mọi đóng góp đều được hoan nghênh!

---

## 📄 License

MIT License
