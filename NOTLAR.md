# OSGB Yazilim - Proje Notlari ve Yapilacaklar

## Tamamlanan Moduller
- [x] Auth (Giris/JWT)
- [x] Firma (CRUD + Excel + Log)
- [x] Isyeri (CRUD + Excel + Log + Geocoding)
- [x] Log Sistemi (form bazli + sistem loglari)
- [x] Excel Import/Export
- [x] Ortak Widgetlar (OrtakForm, OrtakListe, FormBolumBaslik vb.)
- [x] Turkce Lokalizasyon (DatePicker vb.)
- [x] Geocoding (Nominatim + Haritada Goster)

## Siradaki Moduller
- [ ] Calisan (Isyerindeki personel kayitlari)
- [ ] Bolum (Isyeri ici departmanlar)
- [ ] Ziyaret (Saha ziyaret kayitlari)
- [ ] Personel - ISG Uzmani / Isyeri Hekimi / DSP (OSGB calisanlari)
- [ ] Sozlesme/Atama (Isyeri-personel eslestirme)

## Onemli Notlar

### 1. Dokuman Yonetimi (TUM FORMLARA)
Her module (Firma, Isyeri, Calisan, Ziyaret vb.) birden fazla dokuman eklenebilmeli.
- Her turlu dosya formati desteklenmeli (PDF, Word, Excel, resim, vs.)
- Bir kayda birden fazla dokuman eklenebilir
- Polimorfik yapi: ayni dokuman sistemi tum modullerde kullanilir

Ornek kullanimlar:
- Firma: Vergi levhasi, imza sirkuleri, ticaret sicil
- Isyeri: SGK belgesi, risk degerlendirme raporu, acil durum plani
- Calisan: Saglik raporu, egitim sertifikasi, ozluk dosyasi
- Ziyaret: Tutanak, fotograflar, olcum sonuclari

### 2. Mobil GPS Ozelligi (ILERIDE)
- Mobil uygulamada GPS ile konum alma
- Isyeri formunda "GPS ile Bul" butonu
- Ziyaret modulunde otomatik konum kaydi

## Teknik Bilgiler
- Backend: Python 3.12, FastAPI, SQLAlchemy, PostgreSQL 17.6
- Frontend: Flutter 3.27.4 (Web + Mobil)
- DB: osgb_master (ana), osgb_demo (demo tenant)
- Backend port: 8001, Frontend port: 3001
- Test: demo@osgbyazilim.com / demo123
- GitHub: https://github.com/ermeseerdogan/osgb-yazilim
