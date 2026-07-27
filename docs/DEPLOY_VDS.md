# Köyden Şehire - VDS Kurulum Rehberi

Bu döküman, `koyden-sehire-mobil` projesini bir VDS (Sanal Sunucu) üzerinde ayağa kaldırmanız için gerekli adımları açıklar. Uygulama, backend (Go), veritabanı (Postgres + Redis) ve web tabanlı admin panelinden (Flutter Web) oluşmaktadır. 

Dağıtım süreci **GitHub Actions** (`.github/workflows/deploy-vds.yml`) ile tam otomatik hale getirilmiştir. 

## 1. VDS Sunucu Ön Hazırlığı

Sunucunuza (Örn: Ubuntu 22.04) SSH ile bağlanın ve aşağıdaki temel gereksinimleri kurun:

### 1.1. Docker ve Docker Compose Kurulumu
```bash
# Docker kurulumu
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Kullanıcınızı docker grubuna ekleyin (her seferinde sudo yazmamak için)
sudo usermod -aG docker $USER
newgrp docker
```

### 1.2. Proje Dizinini Oluşturma
GitHub Actions, dosyaları buraya kopyalayacaktır:
```bash
sudo mkdir -p /opt/koydensehire
sudo chown -R $USER:$USER /opt/koydensehire
cd /opt/koydensehire

# Repoyu ilk kez manuel klonlayın
git clone https://github.com/<kullanici-adiniz>/koyden-sehire-mobil.git .
```

### 1.3. Ortam Değişkenleri (.env)
Proje kök dizininde `.env` dosyasını oluşturun. API ve veritabanı için gerekli sırları buraya girin:
```bash
nano .env
```
Örnek `.env` içeriği:
```ini
POSTGRES_DB=koydensehire
POSTGRES_USER=admin
POSTGRES_PASSWORD=cok_guvenli_sifre
REDIS_PASSWORD=redis_guvenli_sifre

# JWT ve diğer ayarlar
JWT_SECRET=super_gizli_jwt_anahtari
# ... diğer backend env değişkenleri
```

## 2. GitHub Actions (CI/CD) Yapılandırması

Otomatik dağıtımın çalışması için GitHub deponuzda **Settings > Secrets and variables > Actions** sekmesine gidin ve aşağıdaki **Repository Secrets** değerlerini ekleyin:

- `VDS_HOST`: Sunucunuzun IP adresi (Örn: `192.168.1.50`)
- `VDS_USER`: SSH kullanıcı adınız (Örn: `root` veya `ubuntu`)
- `VDS_SSH_KEY`: Sunucuya bağlanmak için kullanılan Private SSH anahtarı (`-----BEGIN OPENSSH PRIVATE KEY-----` ile başlayan kısım). 
  - *Not: Şifresiz giriş için public key'inizi sunucunun `~/.ssh/authorized_keys` dosyasına eklemeyi unutmayın.*

Bu ayarları yaptıktan sonra `main` branch'ine yapılan her push işlemi projeyi otomatik olarak derleyip VDS üzerinde ayağa kaldıracaktır.

## 3. Manuel Deploy (Opsiyonel)

Eğer GitHub Actions kullanmadan manuel olarak derleyip çalıştırmak isterseniz:

**1. Frontend (Web) Derlemesi (Kendi bilgisayarınızda):**
```bash
cd flutter-mobile
flutter build web --release --dart-define=BASE_URL=/api/v1
# BASE_URL=/api/v1 origin-göreli (same-origin) bir adrestir: web build'i API ile
# aynı domain'den servis edildiğinde nginx zaten /api/v1'i backend'e proxyler.
# Farklı bir domain kullanıyorsanız tam adres verin:
#   --dart-define=BASE_URL=https://api.koydensehire.com/api/v1
# Çıkan build/web klasörünü VDS'de /opt/koydensehire/flutter-mobile/build/web/ içine kopyalayın
```

**2. Backend ve Servisleri Başlatma (VDS üzerinde):**
```bash
cd /opt/koydensehire
docker compose -f docker-compose.prod.yml build --no-cache api
docker compose -f docker-compose.prod.yml up -d
```

## 4. Nginx ve Domain Yönetimi

Docker Compose içerisinde Nginx `80` portundan hizmet verecek şekilde ayarlanmıştır. Eğer sunucuya bir domain (Örn: `admin.koydensehire.com`) bağladıysanız, tarayıcıdan doğrudan erişebilirsiniz.

Eğer SSL (HTTPS) eklemek isterseniz, sunucuya dışarıdan bir `certbot` kurarak veya `docker-compose.prod.yml` içine `certbot` imajını dahil ederek sertifika alabilirsiniz. 

Alternatif olarak, projede yer alan `cloudflared` servisini kullanarak **Cloudflare Tunnel** üzerinden projenizi dış dünyaya güvenle açabilirsiniz. (Tünel kullanacaksanız Nginx'in 80 portu ile tunnel arasındaki yönlendirmeyi Cloudflare Zero Trust panelinden yapılandırmanız gerekir).
