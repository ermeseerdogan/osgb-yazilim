
# OSGB YAZILIMI - PROJE KARARLARI VE TERCİHLER
## Son Güncelleme: 7 Şubat 2026

---
test
## 1. PROJE TANIMI

- **Proje Adı:** OSGB Yönetim Yazılımı
- **Proje Türü:** SaaS (Software as a Service) - Aylık abonelik modeli
- **Amaç:** Türkiye'deki OSGB'ler için kapsamlı, modern, piyasada fark yaratan bir yazılım
- **Proje Klasörü:** D:\Rifki\osgb

---

## 2. TEKNOLOJİ KARARLARI

| Karar | Seçim | Tarih | Not |
|-------|-------|-------|-----|
| Frontend | Flutter (Dart) | 7 Şubat 2026 | Tek kod tabanı, 6 platform |
| Backend | Python FastAPI | 7 Şubat 2026 | Python bilgisi var, AI uyumu |
| Veritabanı | PostgreSQL | 7 Şubat 2026 | Ana veritabanı |
| Offline DB | SQLite + Hive | 7 Şubat 2026 | Cihaz üzerinde |
| Cache/Queue | Redis | 7 Şubat 2026 | Session, cache, Celery queue |
| Dosya Depolama | MinIO | 7 Şubat 2026 | S3 uyumlu, PDF/resim depolama |
| ORM | SQLAlchemy 2.0 | 7 Şubat 2026 | Veritabanı yönetimi |
| Migration | Alembic | 7 Şubat 2026 | Veritabanı versiyonlama |
| Web Sunucu | Nginx + Gunicorn + Uvicorn | 7 Şubat 2026 | Prodüksiyon |
| Konteyner | Docker + Docker Compose | 7 Şubat 2026 | Paketleme ve deploy |
| CI/CD | GitHub Actions | 7 Şubat 2026 | Otomatik yayınlama |

---

## 3. MİMARİ KARARLAR

### 3.1 Multi-Tenant Stratejisi
- **Karar:** Her OSGB'ye AYRI veritabanı (Database per Tenant)
- **Tarih:** 7 Şubat 2026
- **Neden:**
  - Tam veri izolasyonu
  - KVKK uyumu
  - Kolay yedekleme/geri yükleme
  - Müşteri ayrılırsa DB verilebilir
  - SaaS satış argümanı: "Veriniz tamamen izole"
- **Master DB:** Tüm OSGB listesi, abonelikler, ödemeler, sistem ayarları
- **Tenant DB:** Her OSGB kendi firmaları, çalışanları, ziyaretleri vs.

### 3.2 Platform Desteği
- Web (tarayıcı)
- iOS (mobil)
- Android (mobil)
- Windows (masaüstü)
- Mac (masaüstü)
- Linux (masaüstü)
- **Offline çalışma desteği VAR** (SQLite + Hive + Sync Engine)

### 3.3 İş Modeli
- **Model:** SaaS (Aylık abonelik)
- **Sunucu:** Şimdilik localhost'ta geliştirme, sonra bulut (henüz karar verilmedi)
- **Subdomain:** Her OSGB kendi subdomain'i ile erişecek (abc.osgbyazilim.com)

---

## 4. MODÜLLER VE KAPSAM

### 4.1 Temel OSGB Modülleri (Excel Yol Haritasından)
1. ✅ Firma Yönetimi (kayıt, listeleme, arama)
2. ✅ İşyeri Yönetimi (SGK sicil, NACE, tehlike sınıfı, bölüm yönetimi)
3. ✅ ISG İşlemleri (yıllık plan, risk analizi, acil durum, KKD, ISG kurulu)
4. ✅ Ziyaret Yönetimi (program oluşturma, haftalık/aylık takip, uyarılar)
5. ✅ Çalışan Yönetimi (kayıt, eğitim, KKD zimmet, mesleki belge, SMS)
6. ✅ Toplu İşlemler (Excel'den aktarma, toplu kayıt)
7. ✅ Arşiv & Şablonlar (evrak arşivi, doküman şablonları, eğitim videoları)
8. ✅ Kullanıcı & Yetki Yönetimi (roller, yetkilendirme)

### 4.2 Fark Yaratan Özellikler (14 adet)
| # | Özellik | Faz | Durum |
|---|---------|-----|-------|
| 1 | İnteraktif Dashboard & KPI | Faz 1 | Planlandı |
| 2 | QR Kod Saha Kontrol | Faz 1 | Planlandı |
| 3 | Basit Ön Muhasebe (Orta Paket) | Faz 1 | Planlandı |
| 4 | Native Mobil Uygulama (Offline) | Faz 2 | Planlandı |
| 5 | GPS Ziyaret Takibi | Faz 2 | Planlandı |
| 6 | WhatsApp Bildirim | Faz 2 | Planlandı |
| 7 | Çalışan Self-Service Portal | Faz 2 | Planlandı |
| 8 | Yapay Zeka Asistanı | Faz 3 | Planlandı |
| 9 | Drag & Drop Rapor Tasarımcısı | Faz 3 | Planlandı |
| 10 | Prediktif Analiz | Faz 3 | Planlandı |
| 11 | Oyunlaştırma (Gamification) | Faz 4 | Planlandı |
| 12 | IoT Sensör Entegrasyonu | Faz 4 | Planlandı |
| 13 | AR/VR Eğitim Desteği | Faz 4 | Planlandı |
| 14 | E-Fatura Entegrasyonu | Faz 1 | Planlandı (Ön muhasebe içinde) |

### 4.3 Ön Muhasebe Detayı
- **Seçilen Paket:** Orta Paket
- **İçerik:**
  - Gelir/gider takibi
  - Cari hesaplar
  - Tahsilat/ödeme kayıtları
  - Sözleşme bazlı otomatik faturalama
  - E-fatura / e-arşiv entegrasyonu
  - Banka mutabakatı
  - Muhasebe raporları

---

## 5. KULLANICI ROLLERİ

| Rol | Açıklama | Erişim Kapsamı |
|-----|----------|----------------|
| Sistem Admin | SaaS yöneticisi (biz) | Tüm OSGB'ler, abonelik, sistem ayarları |
| OSGB Yöneticisi | Müşteri admin | Kendi OSGB'sinin tüm modülleri |
| ISG Uzmanı | Saha uzmanı | Atandığı firmalar, ziyaret, risk, eğitim |
| İşyeri Hekimi | Sağlık | Atandığı firmalar, muayene, e-reçete |
| DSP | Diğer sağlık personeli | Atandığı firmalar, eğitim, ziyaret |
| İşveren/Vekil | Firma yetkilisi | Sadece kendi firması, salt okunur |
| Çalışan | Self-service | Kendi kayıtları, eğitim, KKD |

---

## 6. ENTEGRASYONLAR

| Entegrasyon | Öncelik | Durum |
|-------------|---------|-------|
| İSG Katip (ÇSGB) | Kritik | Planlandı |
| İBYS (Bakanlık) | Kritik | Planlandı |
| SGK (E-Devlet) | Yüksek | Planlandı |
| E-Fatura / E-Arşiv (GİB) | Yüksek | Planlandı |
| E-Reçete (Medula) | Orta | Planlandı |
| WhatsApp Business API | Orta | Planlandı |
| SMS Gateway (NetGSM vb) | Orta | Planlandı |
| E-Posta (SMTP/SendGrid) | Yüksek | Planlandı |
| Google Maps API | Orta | Planlandı |
| Ödeme Altyapısı (iyzico/PayTR) | Yüksek | Planlandı |

---

## 7. GELİŞTİRME ORTAMI

| Araç | Durum | Not |
|------|-------|-----|
| Windows 10/11 | ✅ Mevcut | İşletim sistemi |
| Python 3.12 | ✅ Kurulu | Backend dili |
| VS Code | ✅ Kurulu | Kod editörü |
| Flutter SDK | ❌ Kurulacak | Frontend framework |
| Dart SDK | ❌ Kurulacak | Flutter ile birlikte gelir |
| Docker Desktop | ❌ Kurulacak | Konteyner yönetimi |
| PostgreSQL | ❌ Kurulacak | Docker ile veya direkt |
| Git | ❓ Kontrol edilecek | Versiyon kontrolü |
| Chrome | ✅ Mevcut (varsayım) | Flutter web testi |

---

## 8. PİYASA ANALİZİ ÖZETİ

### İncelenen Rakipler
- OSGBpro, IRONIC-OSGB/İSGPRO, İSG Katip, Healthy OSGB
- aKareISG, iSGDATA, ISGBYS, MedicoSoft, RiskSoft, TürkGüven

### Rakiplerde Eksik Bulunan Özellikler (Bizim Fırsatımız)
1. Yapay zeka desteği yok
2. Native mobil uygulama çok az
3. Offline çalışma neredeyse hiç yok
4. QR kod saha kontrol çok sınırlı
5. GPS ziyaret takibi yok
6. WhatsApp entegrasyonu yok
7. İnteraktif dashboard zayıf
8. Çalışan self-service portal yok
9. Oyunlaştırma hiç yok
10. IoT entegrasyonu hiç yok
11. Prediktif analiz hiç yok
12. Kullanıcı deneyimi genel olarak kötü
13. Fiyatlandırma şeffaf değil

### Rakiplerde En Çok Şikayet Edilen Konular
- Kötü UI/UX
- Mobil uygulama eksikliği
- Yetersiz teknik destek
- Şeffaf olmayan fiyatlandırma
- İSG Katip entegrasyon sorunları

---

## 9. ÖĞRENİM NOTU

- **Kullanıcı Python ve Flutter bilmiyor**
- Her adımda kod açıklamalı, öğretici şekilde ilerlenecek
- Her satır yorumlanacak, neden böyle yazıldığı anlatılacak
- Gerçek proje üzerinde öğrenme yaklaşımı

---

## 10. FAZ PLANI

### Faz 1 - Temel Altyapı (Öncelik: EN YÜKSEK)
- [ ] Geliştirme ortamı kurulumu (Flutter, Docker, PostgreSQL)
- [ ] Proje iskelet yapısı (backend + frontend)
- [ ] Veritabanı şeması tasarımı
- [ ] Kullanıcı kimlik doğrulama (Auth + JWT)
- [ ] Multi-tenant altyapısı
- [ ] Firma yönetimi modülü
- [ ] İşyeri yönetimi modülü
- [ ] İnteraktif dashboard
- [ ] QR kod saha kontrol
- [ ] Ön muhasebe modülü

### Faz 2 - Mobil & Saha
- [ ] Native mobil uygulama (iOS + Android)
- [ ] Offline çalışma + senkronizasyon
- [ ] GPS ziyaret takibi
- [ ] WhatsApp bildirim
- [ ] Çalışan self-service portal

### Faz 3 - Akıllı Özellikler
- [ ] Yapay zeka asistanı
- [ ] Drag & drop rapor tasarımcısı
- [ ] Prediktif analiz

### Faz 4 - İleri Seviye
- [ ] Oyunlaştırma
- [ ] IoT sensör entegrasyonu
- [ ] AR/VR eğitim desteği

---

## 11. DOSYA HARİTASI

| Dosya | İçerik |
|-------|--------|
| PROGRAM YOL HARİTASI.xlsx | İlk gereksinim dokümanı (Excel) |
| SISTEM_MIMARISI.md | Detaylı teknik mimari |
| PROJE_KARARLARI.md | Bu dosya - tüm kararlar ve tercihler |
| DEVAM_NOTU.md | Her oturumun sonunda güncellenir |
| İnşaat.pdf | Referans doküman - inşaat sektörü |
| makina.pdf | Referans doküman - makina sektörü |
| ofis.pdf | Referans doküman - ofis ortamı |
| depo.pdf | Referans doküman - depo ortamı |
| Kaynak_1.jpg | Referans görsel |
| makine-qr-sistemi.html | QR kod sistemi prototipi |

---

## 12. YENİ OTURUM BAŞLATMA REHBERİ

Yeni bir sohbet açıldığında şunu söyle:

> "D:\Rifki\osgb klasöründeki PROJE_KARARLARI.md ve DEVAM_NOTU.md dosyalarını oku ve kaldığımız yerden devam et"

Claude tüm dosyaları okuyup projeyi anlayacak ve kaldığı yerden devam edecektir.

---

## 13. DEĞİŞİKLİK GEÇMİŞİ

| Tarih | Değişiklik |
|-------|-----------|
| 7 Şubat 2026 | İlk versiyon oluşturuldu. Tüm temel kararlar alındı. |
