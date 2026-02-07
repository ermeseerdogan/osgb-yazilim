# =============================================
# DEPENDENCY'LER (Bagimliliklar)
# Her API isteginde otomatik calisan fonksiyonlar
# =============================================
#
# 📚 DERS: FastAPI'de "Depends" sistemi
#
# Bir API endpoint'i su sekilde yazilir:
#
#   @router.get("/firmalar")
#   def firma_listele(
#       kullanici = Depends(mevcut_kullanici_getir),
#       db = Depends(tenant_db_getir),
#   ):
#       ...
#
# Depends() sayesinde:
# 1. Token otomatik kontrol edilir
# 2. Kullanici bilgisi hazir gelir
# 3. Dogru tenant DB'si otomatik secilir
# 4. Endpoint sadece IS MANTIGI ile ilgilenir
#
# Bu kalip "Dependency Injection" (DI) olarak bilinir.
# Her endpoint'te ayri ayri token kontrol etmek yerine
# bu fonksiyonlari bir kez yaziyoruz, her yerde kullaniyoruz.

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session, sessionmaker
from jose import JWTError

from app.core.security import token_coz
from app.core.database import get_master_db, get_tenant_engine
from app.models.master import Kullanici

# Token'in nereden alinacagini tanimla
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


# =============================================
# 1. MEVCUT KULLANICI GETIR
# Token'dan kullanici bilgisini cikarir
# =============================================
def mevcut_kullanici_getir(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_master_db),
) -> Kullanici:
    """
    📚 DERS: Her korunmus endpoint'te kullanilir.

    Akis:
    1. Frontend istek gonderirken header'a token ekler:
       Authorization: Bearer eyJhbGciOiJ...
    2. Bu fonksiyon token'i alir ve cozer
    3. Token icinden email'i bulur
    4. DB'den kullaniciyi getirir
    5. Endpoint'e hazir kullanici nesnesi verir

    Kullanim:
        @router.get("/profil")
        def profil(kullanici: Kullanici = Depends(mevcut_kullanici_getir)):
            return {"ad": kullanici.ad}
    """
    # Hata mesaji
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Gecersiz veya suresi dolmus token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # Token'i coz
        payload = token_coz(token)
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Kullaniciyi DB'den getir
    kullanici = db.query(Kullanici).filter(
        Kullanici.email == email
    ).first()

    if kullanici is None:
        raise credentials_exception

    if not kullanici.aktif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesabiniz devre disi",
        )

    return kullanici


# =============================================
# 2. TENANT DB SESSION GETIR
# Kullanicinin ait oldugu OSGB'nin DB'sine baglanir
# =============================================
def tenant_db_getir(
    token: str = Depends(oauth2_scheme),
) -> Session:
    """
    📚 DERS: Multi-tenant DB erisimi.

    Her OSGB'nin kendi veritabani var:
    - osgb_demo (Demo OSGB)
    - osgb_abc  (ABC OSGB)
    - osgb_xyz  (XYZ OSGB)

    Bu fonksiyon token'daki db_name bilgisinden
    hangi DB'ye baglanacagini anlar ve session olusturur.

    Akis:
    1. Token'dan db_name'i cikart
    2. O DB'ye engine olustur
    3. Session olustur ve don

    Kullanim:
        @router.get("/firmalar")
        def firmalar(db: Session = Depends(tenant_db_getir)):
            return db.query(Firma).all()
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Gecersiz token",
    )

    try:
        payload = token_coz(token)
        db_name: str = payload.get("db_name")
    except JWTError:
        raise credentials_exception

    # Sistem admin'in tenant DB'si yok
    if not db_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bu islem icin bir OSGB'ye ait olmaniz gerekir",
        )

    # Tenant DB'ye baglan
    engine = get_tenant_engine(db_name)
    SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


# =============================================
# 3. ROL KONTROLU
# Belirli roller icin erisim sinirlamasi
# =============================================
def rol_gerekli(*roller: str):
    """
    📚 DERS: Rol bazli yetkilendirme.

    Bazi endpoint'lere sadece belirli roller erisebilir.
    Ornegin: Firma silme sadece OSGB yoneticisi yapabilir.

    Kullanim:
        @router.delete("/firma/{id}")
        def firma_sil(
            id: int,
            kullanici: Kullanici = Depends(rol_gerekli("sistem_admin", "osgb_yoneticisi")),
        ):
            ...

    Python'daki decorator mantigi ile benzer ama
    FastAPI'nin Depends sistemi ile calisir.
    """
    def kontrol(kullanici: Kullanici = Depends(mevcut_kullanici_getir)):
        if kullanici.rol.value not in roller:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Bu islem icin yetkiniz yok. Gerekli roller: {', '.join(roller)}",
            )
        return kullanici
    return kontrol
