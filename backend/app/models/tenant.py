# =============================================
# TENANT DATABASE MODELLERI
# Her OSGB'nin KENDI veritabanindaki tablolar
# Firma, isyeri, calisan, ziyaret vs. burada
# =============================================

from datetime import datetime, date
from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, Date,
    Text, Float, ForeignKey, Enum, Table,
)
from sqlalchemy.orm import relationship
from app.core.database import Base
import enum


# ---- ENUM TANIMLARI ----

class TehlikeSinifi(str, enum.Enum):
    """Isyeri tehlike sinifi (NACE koduna gore)"""
    AZ_TEHLIKELI = "az_tehlikeli"
    TEHLIKELI = "tehlikeli"
    COK_TEHLIKELI = "cok_tehlikeli"


class KKDTipi(str, enum.Enum):
    """Kisisel koruyucu donanim tipleri"""
    BARET = "baret"
    ELDIVEN = "eldiven"
    GOZLUK = "gozluk"
    KULAKLLIK = "kulakllik"
    MASKE = "maske"
    AYAKKABI = "ayakkabi"
    YELEK = "yelek"
    DIGER = "diger"


class ZiyaretDurumu(str, enum.Enum):
    """Ziyaret durumu"""
    PLANLANDI = "planlandi"
    TAMAMLANDI = "tamamlandi"
    IPTAL = "iptal"
    ERTELENDI = "ertelendi"


class PersonelUnvan(str, enum.Enum):
    """OSGB personel unvanlari"""
    ISG_UZMANI = "isg_uzmani"
    ISYERI_HEKIMI = "isyeri_hekimi"
    DSP = "dsp"


class UzmanlikSinifi(str, enum.Enum):
    """ISG Uzmani uzmanlik sinifi"""
    A_SINIFI = "a_sinifi"
    B_SINIFI = "b_sinifi"
    C_SINIFI = "c_sinifi"


# =============================================
# FIRMA TABLOSU
# Excel'deki "FIRMA KAYDETME" bolumu
# =============================================
class Firma(Base):
    """
    Firma = OSGB'nin hizmet verdigi sirket/kurum.
    Bir OSGB birden fazla firmaya hizmet verir.
    """
    __tablename__ = "firmalar"

    id = Column(Integer, primary_key=True, index=True)

    # Temel bilgiler (Excel'deki zorunlu alanlar)
    ad = Column(String(255), nullable=False)          # Firma adi ve unvani
    kisa_ad = Column(String(16))                       # Kisa ad (max 16 karakter)
    adres = Column(Text)
    il = Column(String(100), nullable=False)
    ilce = Column(String(100), nullable=False)
    email = Column(String(255), nullable=False)
    telefon = Column(String(20), nullable=False)

    # Vergi bilgileri (opsiyonel)
    vergi_dairesi = Column(String(255))
    vergi_no = Column(String(20))

    # Logo
    logo_url = Column(String(500))

    # Durum
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Iliskiler
    isyerleri = relationship("Isyeri", back_populates="firma")

    def __repr__(self):
        return f"<Firma(id={self.id}, ad='{self.ad}')>"


# =============================================
# ISYERI TABLOSU
# Excel'deki "ISYERI KAYIT ISLEMLERI" bolumu
# =============================================
class Isyeri(Base):
    """
    Isyeri = Bir firmaya ait calisma alani.
    Bir firmanin birden fazla isyeri olabilir (fabrika, ofis, depo).
    """
    __tablename__ = "isyerleri"

    id = Column(Integer, primary_key=True, index=True)

    # Hangi firmaya ait?
    firma_id = Column(Integer, ForeignKey("firmalar.id"), nullable=False)
    firma = relationship("Firma", back_populates="isyerleri")

    # Temel bilgiler
    ad = Column(String(255), nullable=False)           # Isyeri adi
    sgk_sicil_no = Column(String(50), nullable=False)  # SGK sicil numarasi
    nace_kodu = Column(String(10), nullable=False)     # 6 haneli NACE kodu
    nace_aciklama = Column(String(500))                 # NACE kodu aciklamasi
    tehlike_sinifi = Column(Enum(TehlikeSinifi), nullable=False)  # NACE'den otomatik
    ana_faaliyet = Column(String(500))                  # Birden fazla yoksa NACE aciklamasi

    # Isveren bilgileri
    isveren_ad = Column(String(100), nullable=False)
    isveren_soyad = Column(String(100), nullable=False)
    isveren_vekili_ad = Column(String(100))             # Opsiyonel
    isveren_vekili_soyad = Column(String(100))

    # ISG profesyonelleri (kullanici ID'leri)
    isg_uzmani_id = Column(Integer)       # Atanan ISG uzmani
    isyeri_hekimi_id = Column(Integer)    # Atanan hekim
    dsp_id = Column(Integer)              # Atanan DSP

    # Hizmet bilgileri
    hizmet_baslama = Column(Date)          # ISG hizmet sozlesmesi tarihi
    ucretlendirme = Column(Float)          # Aylik ucret

    # Mali musavir bilgileri (opsiyonel)
    mali_musavir_ad = Column(String(100))
    mali_musavir_soyad = Column(String(100))
    mali_musavir_telefon = Column(String(20))
    mali_musavir_email = Column(String(255))

    # Konum
    koordinat_lat = Column(Float)          # Enlem
    koordinat_lng = Column(Float)          # Boylam
    lokasyon = Column(String(500))

    # Logo
    logo_url = Column(String(500))

    # Durum
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Iliskiler
    bolumler = relationship("Bolum", back_populates="isyeri")
    calisanlar = relationship("Calisan", back_populates="isyeri")
    ziyaretler = relationship("Ziyaret", back_populates="isyeri")

    def __repr__(self):
        return f"<Isyeri(id={self.id}, ad='{self.ad}', sgk='{self.sgk_sicil_no}')>"


# =============================================
# BOLUM TABLOSU
# Excel'deki "ISYERI BOLUMU" bolumu
# =============================================
class Bolum(Base):
    """
    Isyeri bolumleri. Ilk kayitta otomatik "Isyeri Geneli" olusturulur.
    """
    __tablename__ = "bolumler"

    id = Column(Integer, primary_key=True, index=True)
    isyeri_id = Column(Integer, ForeignKey("isyerleri.id"), nullable=False)
    isyeri = relationship("Isyeri", back_populates="bolumler")

    ad = Column(String(255), nullable=False)  # "Isyeri Geneli", "Uretim", "Depo" vs.
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Bolum(id={self.id}, ad='{self.ad}')>"


# =============================================
# CALISAN TABLOSU
# Excel'deki "CALISAN ISLEMLERI" bolumu
# =============================================
class Calisan(Base):
    """Firmada calisan personel kayitlari"""
    __tablename__ = "calisanlar"

    id = Column(Integer, primary_key=True, index=True)

    # Hangi isyerine ait?
    isyeri_id = Column(Integer, ForeignKey("isyerleri.id"), nullable=False)
    isyeri = relationship("Isyeri", back_populates="calisanlar")

    # Kisisel bilgiler
    tc_no = Column(String(11), unique=True)
    ad = Column(String(100), nullable=False)
    soyad = Column(String(100), nullable=False)
    telefon = Column(String(20))
    email = Column(String(255))
    dogum_tarihi = Column(Date)
    ise_giris_tarihi = Column(Date)

    # Gorev bilgileri
    gorev = Column(String(255))             # "Operator", "Muhendis" vs.
    bolum = Column(String(255))             # Calistigi bolum
    kan_grubu = Column(String(10))

    # Profil fotografi
    profil_foto_url = Column(String(500))

    # Durum
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Iliskiler
    egitimler = relationship("Egitim", back_populates="calisan")
    kkd_zimmetleri = relationship("KKDZimmet", back_populates="calisan")

    def __repr__(self):
        return f"<Calisan(id={self.id}, ad='{self.ad} {self.soyad}')>"


# =============================================
# PERSONEL TABLOSU
# OSGB'nin kendi calisanlari (ISG Uzmani, Isyeri Hekimi, DSP)
# Calisan'dan farki: Belirli bir isyerine degil, OSGB'ye baglilar.
# Sozlesme/Atama moduluyle birden fazla isyerine atanabilirler.
# =============================================
class Personel(Base):
    """OSGB personeli: ISG Uzmani, Isyeri Hekimi, DSP"""
    __tablename__ = "personeller"

    id = Column(Integer, primary_key=True, index=True)

    # Kisisel bilgiler
    ad = Column(String(100), nullable=False)
    soyad = Column(String(100), nullable=False)
    tc_no = Column(String(11), unique=True, index=True)
    telefon = Column(String(20))
    email = Column(String(255))

    # Unvan (zorunlu)
    unvan = Column(Enum(PersonelUnvan), nullable=False, index=True)

    # Mesleki bilgiler
    uzmanlik_belgesi_no = Column(String(100))
    diploma_no = Column(String(100))
    uzmanlik_sinifi = Column(Enum(UzmanlikSinifi))  # Sadece ISG Uzmani icin
    brans = Column(String(255))                      # Sadece Isyeri Hekimi icin

    # Calisma bilgileri
    ise_baslama_tarihi = Column(Date)

    # Kullanici baglantisi (opsiyonel - sisteme giris yapabilir)
    kullanici_id = Column(Integer, index=True)

    # Profil fotografi
    profil_foto_url = Column(String(500))

    # Durum
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<Personel(id={self.id}, ad='{self.ad} {self.soyad}', unvan='{self.unvan}')>"


# =============================================
# EGITIM TABLOSU
# =============================================
class Egitim(Base):
    """Calisanlara verilen egitim kayitlari"""
    __tablename__ = "egitimler"

    id = Column(Integer, primary_key=True, index=True)

    calisan_id = Column(Integer, ForeignKey("calisanlar.id"), nullable=False)
    calisan = relationship("Calisan", back_populates="egitimler")

    egitim_adi = Column(String(500), nullable=False)
    egitim_tarihi = Column(Date, nullable=False)
    egitim_suresi = Column(Float)              # Saat cinsinden
    egitimci = Column(String(255))             # Egitimi veren kisi
    sertifika_no = Column(String(100))
    sertifika_url = Column(String(500))        # Dosya yolu
    gecerlilik_tarihi = Column(Date)           # Ne zamana kadar gecerli

    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Egitim(id={self.id}, ad='{self.egitim_adi}')>"


# =============================================
# KKD ZIMMET TABLOSU
# =============================================
class KKDZimmet(Base):
    """Kisisel Koruyucu Donanim zimmet kayitlari"""
    __tablename__ = "kkd_zimmetleri"

    id = Column(Integer, primary_key=True, index=True)

    calisan_id = Column(Integer, ForeignKey("calisanlar.id"), nullable=False)
    calisan = relationship("Calisan", back_populates="kkd_zimmetleri")

    kkd_tipi = Column(Enum(KKDTipi), nullable=False)
    kkd_aciklama = Column(String(255))          # "3M 6200 Maske" gibi
    teslim_tarihi = Column(Date, nullable=False)
    teslim_alan_imza = Column(Boolean, default=False)  # Imza alindi mi?

    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<KKDZimmet(id={self.id}, tip='{self.kkd_tipi}')>"


# =============================================
# ZIYARET TABLOSU
# Excel'deki "ZIYARET PROGRAMLARI" ve "SAHA DENETIM" bolumu
# =============================================
class Ziyaret(Base):
    """ISG profesyonellerinin isyeri ziyaret kayitlari"""
    __tablename__ = "ziyaretler"

    id = Column(Integer, primary_key=True, index=True)

    isyeri_id = Column(Integer, ForeignKey("isyerleri.id"), nullable=False)
    isyeri = relationship("Isyeri", back_populates="ziyaretler")

    # Ziyaret bilgileri
    ziyaretci_id = Column(Integer)             # Ziyareti yapan ISG profesyoneli
    ziyaretci_adi = Column(String(255))
    ziyaret_tarihi = Column(DateTime, nullable=False)
    ziyaret_bitis = Column(DateTime)
    durum = Column(Enum(ZiyaretDurumu), default=ZiyaretDurumu.PLANLANDI)

    # Ziyaret detaylari
    notlar = Column(Text)                       # Ziyaret notlari
    gps_lat = Column(Float)                     # Check-in lokasyonu
    gps_lng = Column(Float)

    # OSGB yetkilisi onayi (Excel'de belirtilmis)
    onaylandi = Column(Boolean, default=False)
    onaylayan_id = Column(Integer)
    onay_tarihi = Column(DateTime)

    # Isverene e-posta gonderildi mi?
    isveren_bilgilendirildi = Column(Boolean, default=False)

    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Ziyaret(id={self.id}, tarih='{self.ziyaret_tarihi}')>"


# =============================================
# DOKUMAN TABLOSU
# 📚 DERS: Polimorfik dokuman sistemi.
# Ayni tablo tum moduller icin kullanilir.
# kaynak_tipi = "firma", "isyeri", "calisan" vs.
# kaynak_id = ilgili kaydin ID'si
# Boylece her module ayni dokuman sistemiyle dosya eklenebilir.
# =============================================
class Dokuman(Base):
    """
    Tum modullere eklenebilen dokuman/dosya kayitlari.
    Ornek: Firma'ya vergi levhasi, Isyeri'ne risk raporu,
    Calisan'a saglik raporu eklenebilir.
    """
    __tablename__ = "dokumanlar"

    id = Column(Integer, primary_key=True, index=True)

    # 📚 DERS: Polimorfik iliski
    # kaynak_tipi + kaynak_id ile hangi kayda ait oldugu belirlenir
    # Ornek: kaynak_tipi="firma", kaynak_id=5 → 5 numarali firmaya ait
    kaynak_tipi = Column(String(50), nullable=False, index=True)  # "firma", "isyeri", "calisan" vs.
    kaynak_id = Column(Integer, nullable=False, index=True)        # Ilgili kaydin ID'si

    # Dosya bilgileri
    dosya_adi = Column(String(500), nullable=False)      # Kullanicinin yukleme sirasindaki dosya adi
    dosya_yolu = Column(String(1000), nullable=False)    # Sunucudaki dosya yolu
    dosya_tipi = Column(String(100))                      # MIME type: application/pdf, image/jpeg vs.
    dosya_boyutu = Column(Integer)                        # Byte cinsinden boyut
    aciklama = Column(String(500))                        # Kullanicinin girdigi aciklama

    # Yukleyen bilgisi
    yukleyen_id = Column(Integer)                         # Yukleyen kullanicinin ID'si
    yukleyen_adi = Column(String(255))                    # Yukleyen kullanicinin adi

    # Durum
    aktif = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    def __repr__(self):
        return f"<Dokuman(id={self.id}, dosya='{self.dosya_adi}', kaynak='{self.kaynak_tipi}:{self.kaynak_id}')>"


# =============================================
# ON MUHASEBE TABLOLARI
# =============================================
class CariHesap(Base):
    """Gelir/gider takibi icin cari hesaplar"""
    __tablename__ = "cari_hesaplar"

    id = Column(Integer, primary_key=True, index=True)

    firma_id = Column(Integer, ForeignKey("firmalar.id"))
    hesap_adi = Column(String(255), nullable=False)
    hesap_tipi = Column(String(50))               # "musteri", "tedarikci"
    bakiye = Column(Float, default=0.0)

    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Fatura(Base):
    """Fatura kayitlari"""
    __tablename__ = "faturalar"

    id = Column(Integer, primary_key=True, index=True)

    firma_id = Column(Integer, ForeignKey("firmalar.id"), nullable=False)
    cari_hesap_id = Column(Integer, ForeignKey("cari_hesaplar.id"))

    fatura_no = Column(String(50), unique=True)
    fatura_tipi = Column(String(20))              # "satis", "alis"
    fatura_tarihi = Column(Date, nullable=False)
    vade_tarihi = Column(Date)
    toplam_tutar = Column(Float, nullable=False)
    kdv_tutar = Column(Float, default=0.0)
    genel_toplam = Column(Float, nullable=False)
    odendi = Column(Boolean, default=False)
    aciklama = Column(Text)

    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)
