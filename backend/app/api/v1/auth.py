# =============================================
# AUTH API ENDPOINT'LERI
# POST /api/v1/auth/login  -> Kullanici girisi
# GET  /api/v1/auth/ben     -> Mevcut kullanici bilgisi
# =============================================

# 📚 DERS: APIRouter nedir?
# FastAPI'de endpoint'leri gruplama araci.
# auth.py -> /auth/login, /auth/ben
# firma.py -> /firma/listele, /firma/ekle
# Boylece main.py temiz kalir!

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from jose import JWTError

from app.core.database import get_master_db
from app.core.security import token_coz
from app.schemas.auth import LoginRequest, TokenResponse, KullaniciBilgi
from app.services.auth_service import kullanici_giris
from app.models.master import Kullanici, Tenant

# ---- ROUTER OLUSTUR ----
router = APIRouter(
    prefix="/auth",    # Bu dosyadaki tum endpoint'ler /auth ile baslar
    tags=["Kimlik Dogrulama"],  # Swagger dokumaninda gruplama
)

# 📚 DERS: OAuth2PasswordBearer
# Frontend'in token'i nasil gonderecegini tanimlar.
# Authorization: Bearer eyJhbGciOiJ...
# tokenUrl: Login endpoint'in adresi
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


# =============================================
# POST /api/v1/auth/login
# Kullanici giris yapar, JWT token alir
# =============================================
@router.post("/login", response_model=TokenResponse)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_master_db),
):
    """
    📚 DERS: Login endpoint'i.

    OAuth2PasswordRequestForm kullaniyoruz cunku:
    1. Swagger UI'da (localhost:8000/docs) "Authorize" butonu calissin
    2. Standart OAuth2 protokolune uygun olsun

    form_data.username = Email (OAuth2 standardi "username" diyor)
    form_data.password = Sifre

    Depends(get_master_db):
    - FastAPI otomatik olarak DB oturumu olusturur
    - Endpoint bitince oturumu kapatir
    - Buna "Dependency Injection" denir
    """
    return kullanici_giris(
        email=form_data.username,   # OAuth2'de email yerine username kullanilir
        sifre=form_data.password,
        db=db,
    )


# =============================================
# JSON ile login (Flutter icin)
# POST /api/v1/auth/login/json
# =============================================
@router.post("/login/json", response_model=TokenResponse)
def login_json(
    login_data: LoginRequest,
    db: Session = Depends(get_master_db),
):
    """
    📚 DERS: JSON login endpoint'i.

    Flutter uygulamasi JSON gonderir:
    {
        "email": "admin@osgbyazilim.com",
        "sifre": "admin123"
    }

    Bu endpoint o JSON'u alir ve giris yapar.
    Ayri bir endpoint cunku OAuth2 form-data kullanir,
    Flutter ise JSON gonderir.
    """
    return kullanici_giris(
        email=login_data.email,
        sifre=login_data.sifre,
        db=db,
    )


# =============================================
# GET /api/v1/auth/ben
# Mevcut kullanicinin bilgilerini dondurur
# =============================================
@router.get("/ben", response_model=KullaniciBilgi)
def mevcut_kullanici(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_master_db),
):
    """
    📚 DERS: Token ile kullanici bilgisi alma.

    Frontend her istekte token gonderir:
    Authorization: Bearer eyJhbGciOiJ...

    Bu endpoint token'i cozer ve kullanici bilgisini dondurur.
    Dashboard'da "Hosgeldin Ahmet" yazmak icin kullanilir.
    """
    # Token'i coz
    try:
        payload = token_coz(token)
        email: str = payload.get("sub")
        if email is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Gecersiz token",
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token suresi dolmus veya gecersiz",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Kullaniciyi bul
    kullanici = db.query(Kullanici).filter(
        Kullanici.email == email
    ).first()

    if not kullanici:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kullanici bulunamadi",
        )

    # Tenant bilgisi
    tenant_ad = None
    db_name = None
    if kullanici.tenant_id:
        tenant = db.query(Tenant).filter(
            Tenant.id == kullanici.tenant_id
        ).first()
        if tenant:
            tenant_ad = tenant.ad
            db_name = tenant.db_name

    return KullaniciBilgi(
        id=kullanici.id,
        email=kullanici.email,
        ad=kullanici.ad,
        soyad=kullanici.soyad,
        rol=kullanici.rol.value,
        tenant_id=kullanici.tenant_id,
        tenant_ad=tenant_ad,
        db_name=db_name,
    )
