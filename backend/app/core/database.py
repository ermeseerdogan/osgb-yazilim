# =============================================
# VERİTABANI BAĞLANTI YÖNETİMİ
# Multi-tenant: Her OSGB'nin kendi veritabanı var
# =============================================

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session, DeclarativeBase
from urllib.parse import quote_plus

from app.core.config import settings


class Base(DeclarativeBase):
    """
    📚 DERS: Tüm veritabanı modelleri bu sınıftan türetilir.

    DeclarativeBase = SQLAlchemy'nin temel sınıfı
    Yeni bir tablo oluşturmak istediğinde:

    class Firma(Base):
        __tablename__ = "firmalar"
        id = Column(Integer, primary_key=True)
        ad = Column(String)

    Bu şekilde Python sınıfı yazarsın,
    SQLAlchemy bunu PostgreSQL tablosuna çevirir.
    SQL yazmana gerek kalmaz!
    """
    pass


# --- MASTER DATABASE BAĞLANTISI ---
# Master DB: Tüm OSGB'lerin listesi, abonelikler, sistem ayarları
master_engine = create_engine(
    settings.DATABASE_URL,  # postgresql://postgres:şifre@localhost:5432/osgb_master
    echo=settings.DEBUG,    # DEBUG=True ise SQL sorgularını konsola yazdır (öğrenme için harika!)
)

# Session: Veritabanı ile konuşmak için kullanılan "telefon hattı"
MasterSessionLocal = sessionmaker(
    bind=master_engine,     # Bu engine'i kullan
    autocommit=False,       # Otomatik kaydetme (biz kontrol edeceğiz)
    autoflush=False,        # Otomatik gönderme kapalı
)


def get_master_db() -> Session:
    """
    📚 DERS: Bu fonksiyon her API isteğinde çağrılır.

    yield = "geçici olarak ver, işi bitince geri al"

    Akış:
    1. Yeni bir veritabanı oturumu (session) aç
    2. API endpoint'e ver (yield)
    3. Endpoint işini bitirince oturumu kapat (finally)

    Bu kalıba "Dependency Injection" denir.
    FastAPI otomatik olarak yönetir.
    """
    db = MasterSessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_tenant_engine(db_name: str):
    """
    📚 DERS: Belirli bir OSGB'nin veritabanına bağlantı oluşturur.

    Örnek: get_tenant_engine("osgb_abc")
    → postgresql://postgres:şifre@localhost:5432/osgb_abc

    Her OSGB'nin kendi veritabanı olduğu için,
    kullanıcı giriş yapınca hangi DB'ye bağlanacağını bilmemiz lazım.
    """
    pwd = quote_plus(settings.DATABASE_PASSWORD)
    tenant_url = (
        f"postgresql://{settings.DATABASE_USER}:{pwd}"
        f"@{settings.DATABASE_HOST}:{settings.DATABASE_PORT}/{db_name}"
    )
    return create_engine(tenant_url, echo=settings.DEBUG)


def get_tenant_session(db_name: str) -> Session:
    """
    📚 DERS: OSGB'nin veritabanı oturumunu oluşturur.

    1. Kullanıcı giriş yapıyor → JWT token'dan tenant bilgisi alınıyor
    2. Bu fonksiyon çağrılıyor → ilgili DB'ye bağlanıyor
    3. API endpoint bu session'ı kullanarak veri okur/yazar
    """
    engine = get_tenant_engine(db_name)
    SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
