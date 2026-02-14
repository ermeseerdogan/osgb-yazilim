"""
Veritabani olusturma scripti.
Bu dosya bir kez calistirilir:
1. Master DB olusturur (osgb_master)
2. Tablolari olusturur
3. Varsayilan admin kullanicisi ekler
4. Ornek bir tenant (OSGB) olusturur
"""

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from app.core.config import settings
from app.core.database import Base, master_engine
from app.models.master import Tenant, Kullanici, RolEnum, AbonelikDurumEnum
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

# Sifre hashleme
from passlib.context import CryptContext
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def veritabani_olustur():
    """PostgreSQL'de osgb_master veritabanini olustur"""
    print("1. Master veritabani olusturuluyor...")

    try:
        # PostgreSQL'e baglan (varsayilan 'postgres' DB'sine)
        conn = psycopg2.connect(
            host=settings.DATABASE_HOST,
            port=settings.DATABASE_PORT,
            user=settings.DATABASE_USER,
            password=settings.DATABASE_PASSWORD,
            database="postgres"  # Varsayilan DB
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()

        # osgb_master DB var mi kontrol et
        cursor.execute(
            "SELECT 1 FROM pg_catalog.pg_database WHERE datname = %s",
            (settings.DATABASE_NAME,)
        )
        exists = cursor.fetchone()

        if not exists:
            cursor.execute(f"CREATE DATABASE {settings.DATABASE_NAME}")
            print(f"   '{settings.DATABASE_NAME}' veritabani olusturuldu!")
        else:
            print(f"   '{settings.DATABASE_NAME}' zaten mevcut.")

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"   HATA: {e}")
        return False

    return True


def tablolari_olustur():
    """SQLAlchemy ile tablolari olustur"""
    print("2. Tablolar olusturuluyor...")

    try:
        Base.metadata.create_all(bind=master_engine)
        print("   Tum tablolar olusturuldu!")
    except Exception as e:
        print(f"   HATA: {e}")
        return False

    return True


def admin_olustur():
    """Varsayilan sistem admin kullanicisi olustur"""
    print("3. Admin kullanicisi olusturuluyor...")

    from sqlalchemy.orm import sessionmaker
    SessionLocal = sessionmaker(bind=master_engine)
    db = SessionLocal()

    try:
        # Admin zaten var mi?
        mevcut = db.query(Kullanici).filter(
            Kullanici.email == "admin@osgbyazilim.com"
        ).first()

        if mevcut:
            print("   Admin zaten mevcut.")
            return True

        # Admin olustur
        admin = Kullanici(
            email="admin@osgbyazilim.com",
            sifre_hash=pwd_context.hash("admin123"),  # Sifre: admin123
            ad="Sistem",
            soyad="Admin",
            rol=RolEnum.SISTEM_ADMIN,
            aktif=True,
            email_dogrulandi=True,
        )
        db.add(admin)
        db.commit()
        print("   Admin olusturuldu!")
        print("   Email: admin@osgbyazilim.com")
        print("   Sifre: admin123")

    except Exception as e:
        db.rollback()
        print(f"   HATA: {e}")
        return False
    finally:
        db.close()

    return True


def ornek_tenant_olustur():
    """Ornek bir OSGB olustur (test icin)"""
    print("4. Ornek OSGB olusturuluyor...")

    from sqlalchemy.orm import sessionmaker
    SessionLocal = sessionmaker(bind=master_engine)
    db = SessionLocal()

    try:
        # Zaten var mi?
        mevcut = db.query(Tenant).filter(Tenant.db_name == "osgb_demo").first()
        if mevcut:
            print("   Ornek OSGB zaten mevcut.")
            return True

        # Ornek OSGB olustur
        tenant = Tenant(
            ad="Demo OSGB Ltd.",
            db_name="osgb_demo",
            subdomain="demo",
            email="demo@osgbyazilim.com",
            telefon="0212 555 1234",
            adres="Istanbul, Kadikoy",
            il="Istanbul",
            ilce="Kadikoy",
            abonelik_durum=AbonelikDurumEnum.DENEME,
            abonelik_baslangic=datetime.utcnow(),
            abonelik_bitis=datetime.utcnow() + timedelta(days=14),
            max_isyeri=50,
            max_kullanici=10,
        )
        db.add(tenant)
        db.commit()

        # Demo OSGB icin yonetici kullanicisi
        yonetici = Kullanici(
            email="demo@osgbyazilim.com",
            sifre_hash=pwd_context.hash("demo123"),
            ad="Demo",
            soyad="Yonetici",
            rol=RolEnum.OSGB_YONETICISI,
            tenant_id=tenant.id,
            aktif=True,
            email_dogrulandi=True,
        )
        db.add(yonetici)
        db.commit()

        print("   Demo OSGB olusturuldu!")
        print("   OSGB Yonetici Email: demo@osgbyazilim.com")
        print("   OSGB Yonetici Sifre: demo123")

    except Exception as e:
        db.rollback()
        print(f"   HATA: {e}")
        return False
    finally:
        db.close()

    return True


def tenant_db_olustur(db_name: str):
    """Yeni bir tenant icin veritabani olustur"""
    print(f"5. Tenant veritabani olusturuluyor: {db_name}...")

    try:
        conn = psycopg2.connect(
            host=settings.DATABASE_HOST,
            port=settings.DATABASE_PORT,
            user=settings.DATABASE_USER,
            password=settings.DATABASE_PASSWORD,
            database="postgres"
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()

        cursor.execute(
            "SELECT 1 FROM pg_catalog.pg_database WHERE datname = %s",
            (db_name,)
        )
        exists = cursor.fetchone()

        if not exists:
            cursor.execute(f"CREATE DATABASE {db_name}")
            print(f"   '{db_name}' veritabani olusturuldu!")
        else:
            print(f"   '{db_name}' zaten mevcut.")

        cursor.close()
        conn.close()

        # Tenant tablolarini olustur
        from app.core.database import get_tenant_engine
        from app.models.tenant import (
            Firma, Isyeri, Bolum, Calisan, Personel,
            Egitim, KKDZimmet, Ziyaret,
            CariHesap, Fatura,
        )
        tenant_engine = get_tenant_engine(db_name)
        Base.metadata.create_all(bind=tenant_engine)
        print(f"   '{db_name}' tablolari olusturuldu!")

    except Exception as e:
        print(f"   HATA: {e}")
        return False

    return True


if __name__ == "__main__":
    print("=" * 50)
    print("OSGB YAZILIMI - VERITABANI KURULUMU")
    print("=" * 50)
    print()

    # 1. Master DB olustur
    if not veritabani_olustur():
        exit(1)

    # 2. Tablolari olustur
    if not tablolari_olustur():
        exit(1)

    # 3. Admin kullanici olustur
    if not admin_olustur():
        exit(1)

    # 4. Ornek tenant olustur
    if not ornek_tenant_olustur():
        exit(1)

    # 5. Demo tenant DB olustur
    if not tenant_db_olustur("osgb_demo"):
        exit(1)

    print()
    print("=" * 50)
    print("KURULUM TAMAMLANDI!")
    print("=" * 50)
    print()
    print("Giris bilgileri:")
    print("  Sistem Admin : admin@osgbyazilim.com / admin123")
    print("  Demo OSGB    : demo@osgbyazilim.com / demo123")
