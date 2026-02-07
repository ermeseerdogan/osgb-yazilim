# =============================================
# MASTER DATABASE MODELLERI
# Tum OSGB'lerin listesi, sistem kullanicilari,
# abonelikler burada tutulur
# =============================================

# datetime: Tarih ve saat islemleri icin
from datetime import datetime

# SQLAlchemy: Veritabani tablo tanimlari
from sqlalchemy import (
    Column,         # Sutun tanimlamak icin
    Integer,        # Tam sayi tipi (1, 2, 3...)
    String,         # Metin tipi ("abc", "xyz")
    Boolean,        # True/False tipi
    DateTime,       # Tarih/saat tipi
    Text,           # Uzun metin tipi
    ForeignKey,     # Baska tabloya referans (iliski)
    Enum,           # Secenekli tip (admin, uzman, hekim...)
    JSON,           # JSON veri tipi (esnek veri saklama)
)
from sqlalchemy.orm import relationship  # Tablolar arasi iliski

# Kendi Base sinifimiz (database.py'de tanimladik)
from app.core.database import Base

import enum  # Python enum (secenekler) icin


# ---- ROLLER ----
# Enum: Belirli seceneklerden biri olmali
# Python'daki enum ile ayni mantik
class RolEnum(str, enum.Enum):
    """
    Sistemdeki kullanici rolleri.
    str'den de turetiyoruz ki veritabaninda metin olarak saklansin.
    """
    SISTEM_ADMIN = "sistem_admin"       # Biz - SaaS yoneticisi
    OSGB_YONETICISI = "osgb_yoneticisi" # Musteri admin
    ISG_UZMANI = "isg_uzmani"           # Saha uzmani
    ISYERI_HEKIMI = "isyeri_hekimi"     # Hekim
    DSP = "dsp"                          # Diger saglik personeli
    ISVEREN = "isveren"                  # Firma yetkilisi
    CALISAN = "calisan"                  # Self-service portal


class AbonelikDurumEnum(str, enum.Enum):
    """Abonelik durumu"""
    AKTIF = "aktif"
    PASIF = "pasif"
    DENEME = "deneme"         # 14 gunluk deneme
    SURESI_DOLMUS = "suresi_dolmus"


# ---- OSGB (TENANT) TABLOSU ----
class Tenant(Base):
    """
    📚 DERS: Her OSGB bir "tenant" (kiraci).
    Bu tablo tum OSGB musterilerinin listesini tutar.

    Ornek kayit:
    id=1, ad="ABC OSGB", db_name="osgb_abc", durum="aktif"
    """
    __tablename__ = "tenants"  # PostgreSQL'deki tablo adi

    # Sutunlar (kolonlar)
    id = Column(Integer, primary_key=True, index=True)
    # primary_key: Bu sutun her kaydi benzersiz tanimlar
    # index: Aramalar hizli olsun diye indeks olustur

    ad = Column(String(255), nullable=False)
    # nullable=False: Bu alan bos birakilamaz (zorunlu)

    db_name = Column(String(100), unique=True, nullable=False)
    # unique=True: Ayni isimde iki DB olamaz
    # Ornek: "osgb_abc", "osgb_xyz"

    subdomain = Column(String(100), unique=True)
    # Ornek: "abc" -> abc.osgbyazilim.com

    # Iletisim bilgileri
    email = Column(String(255))
    telefon = Column(String(20))
    adres = Column(Text)           # Text = uzun metin
    il = Column(String(100))
    ilce = Column(String(100))

    # Vergi bilgileri
    vergi_dairesi = Column(String(255))
    vergi_no = Column(String(20))

    # Abonelik
    abonelik_durum = Column(
        Enum(AbonelikDurumEnum),
        default=AbonelikDurumEnum.DENEME  # Yeni kayitlarda varsayilan
    )
    abonelik_baslangic = Column(DateTime)
    abonelik_bitis = Column(DateTime)
    max_isyeri = Column(Integer, default=50)     # Maksimum isyeri sayisi
    max_kullanici = Column(Integer, default=10)  # Maksimum kullanici

    # Logo
    logo_url = Column(String(500))

    # Sistem alanlari
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Iliskiler: Bu tenant'a ait kullanicilar
    kullanicilar = relationship("Kullanici", back_populates="tenant")

    def __repr__(self):
        """Python'da print(tenant) yazinca gorunecek yazi"""
        return f"<Tenant(id={self.id}, ad='{self.ad}', db='{self.db_name}')>"


# ---- KULLANICI TABLOSU ----
class Kullanici(Base):
    """
    📚 DERS: Sistem kullanicilari.
    Her kullanici bir OSGB'ye (tenant) aittir.

    Ornek kayit:
    id=1, email="ahmet@abc.com", rol="isg_uzmani", tenant_id=1
    """
    __tablename__ = "kullanicilar"

    id = Column(Integer, primary_key=True, index=True)

    # Kimlik bilgileri
    email = Column(String(255), unique=True, nullable=False, index=True)
    sifre_hash = Column(String(255), nullable=False)
    # sifre_hash: Sifre duz metin olarak ASLA saklanmaz!
    # "123456" -> "$2b$12$LJ3..." gibi hash'lenir (geri donusturulemez)

    # Kisisel bilgiler
    ad = Column(String(100), nullable=False)
    soyad = Column(String(100), nullable=False)
    telefon = Column(String(20))
    unvan = Column(String(100))  # "A Sinifi ISG Uzmani" gibi

    # Rol ve yetki
    rol = Column(Enum(RolEnum), nullable=False)
    # Ornek: RolEnum.ISG_UZMANI, RolEnum.OSGB_YONETICISI

    # Hangi OSGB'ye ait?
    tenant_id = Column(Integer, ForeignKey("tenants.id"))
    # ForeignKey: Bu alan "tenants" tablosundaki "id" alanina referans verir
    # Yani her kullanici bir OSGB'ye baglidir

    # Iliski: Bu kullanicinin ait oldugu OSGB
    tenant = relationship("Tenant", back_populates="kullanicilar")

    # Durum
    aktif = Column(Boolean, default=True)
    email_dogrulandi = Column(Boolean, default=False)
    son_giris = Column(DateTime)

    # Sistem alanlari
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<Kullanici(id={self.id}, email='{self.email}', rol='{self.rol}')>"


# ---- ISLEM LOG (AUDIT LOG) TABLOSU ----
class IslemLogEnum(str, enum.Enum):
    """Log islem turleri"""
    GIRIS = "giris"                  # Kullanici giris yapti
    CIKIS = "cikis"                  # Kullanici cikis yapti
    GIRIS_BASARISIZ = "giris_basarisiz"  # Yanlis sifre denendi
    KAYIT_EKLEME = "kayit_ekleme"    # Yeni kayit eklendi
    KAYIT_GUNCELLEME = "kayit_guncelleme"  # Kayit guncellendi
    KAYIT_SILME = "kayit_silme"      # Kayit silindi
    YETKI_HATASI = "yetki_hatasi"    # Yetkisiz erisim denemesi
    SIFRE_DEGISTIRME = "sifre_degistirme"  # Sifre degistirildi
    SISTEM = "sistem"                # Sistem olayi


class IslemLog(Base):
    """
    📚 DERS: Audit Log (Denetim Kaydi)

    Sistemde yapilan HER ISLEMI kaydeder:
    - Kim yapti? (kullanici_id, email)
    - Ne zaman yapti? (tarih)
    - Ne yapti? (islem_turu, aciklama)
    - Nerede yapti? (modul, ip_adresi)
    - Eski/yeni deger ne? (eski_deger, yeni_deger)

    Bu kayitlar:
    1. Guvenlik icin onemli (kim ne yapti?)
    2. Yasal zorunluluk (KVKK, is guvenligi mevzuati)
    3. Hata takibi (ne zaman bozuldu?)
    4. Kullanici davranisi analizi
    """
    __tablename__ = "islem_loglari"

    id = Column(Integer, primary_key=True, index=True)

    # Kim yapti?
    kullanici_id = Column(Integer, ForeignKey("kullanicilar.id"), nullable=True)
    kullanici_email = Column(String(255))  # Email ayrica saklanir (kullanici silinse bile log kalir)
    kullanici_rol = Column(String(50))
    kullanici_ad = Column(String(200))

    # Hangi OSGB?
    tenant_id = Column(Integer, nullable=True)
    tenant_ad = Column(String(255), nullable=True)

    # Ne yapti?
    islem_turu = Column(Enum(IslemLogEnum), nullable=False, index=True)
    modul = Column(String(100), index=True)  # "firma", "calisan", "ziyaret" vs.
    aciklama = Column(Text)                  # Okunabilir aciklama

    # Hangi kayit uzerinde?
    kayit_id = Column(Integer, nullable=True)       # Etkilenen kayitin ID'si
    kayit_turu = Column(String(100), nullable=True)  # "Firma", "Calisan" vs.

    # Eski ve yeni deger (JSON formatinda)
    eski_deger = Column(JSON, nullable=True)  # Guncelleme/silme oncesi
    yeni_deger = Column(JSON, nullable=True)  # Guncelleme/ekleme sonrasi

    # Teknik bilgiler
    ip_adresi = Column(String(50))             # Ic IP (yerel ag adresi)
    dis_ip_adresi = Column(String(50), nullable=True)  # Dis IP (internet/public IP)
    user_agent = Column(String(500))      # Tarayici/cihaz bilgisi
    http_metod = Column(String(10))       # GET, POST, PUT, DELETE
    endpoint = Column(String(500))        # /api/v1/firma

    # Sonuc
    basarili = Column(Boolean, default=True)
    hata_mesaji = Column(Text, nullable=True)

    # Zaman
    tarih = Column(DateTime, default=datetime.utcnow, index=True)

    def __repr__(self):
        return f"<IslemLog(id={self.id}, islem='{self.islem_turu}', kullanici='{self.kullanici_email}')>"
