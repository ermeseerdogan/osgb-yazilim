# =============================================
# GUVENLIK ARACLARI
# Sifre hashleme ve JWT token islemleri
# =============================================

from datetime import datetime, timedelta
from typing import Optional

# JWT token olusturma/dogrulama
from jose import JWTError, jwt

# Sifre hashleme (sifreyi geri donusturulemez hale getirir)
from passlib.context import CryptContext

from app.core.config import settings


# ---- SIFRE HASHLEME ----
# bcrypt: En guvenlisifre hashleme algoritmasi
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def sifre_hashle(sifre: str) -> str:
    """
    Sifre -> Hash donusumu.

    Ornek: "admin123" -> "$2b$12$LJ3m5..."
    Bu hash'ten orijinal sifreye geri donulemez!
    """
    return pwd_context.hash(sifre)


def sifre_dogrula(duz_sifre: str, hash_sifre: str) -> bool:
    """
    Kullanicinin girdigi sifre ile DB'deki hash'i karsilastir.

    Ornek: sifre_dogrula("admin123", "$2b$12$LJ3m5...") -> True
    """
    return pwd_context.verify(duz_sifre, hash_sifre)


# ---- JWT TOKEN ----

def token_olustur(data: dict, sure: Optional[timedelta] = None) -> str:
    """
    JWT token olustur.

    data icerigi:
    {
        "sub": "admin@osgbyazilim.com",  # Kullanici email
        "user_id": 1,                     # Kullanici ID
        "rol": "sistem_admin",            # Rol
        "tenant_id": null,                # OSGB ID (admin icin null)
        "db_name": null,                  # DB adi (admin icin null)
    }
    """
    # Veriyi kopyala (orijinali degistirmeyelim)
    to_encode = data.copy()

    # Token suresi
    if sure:
        bitis = datetime.utcnow() + sure
    else:
        bitis = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )

    # "exp" = expiration (son kullanma tarihi)
    to_encode.update({"exp": bitis})

    # Token'i olustur ve dondur
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,    # Gizli anahtar ile imzala
        algorithm=settings.ALGORITHM  # HS256 algoritmasi
    )
    return encoded_jwt


def token_coz(token: str) -> dict:
    """
    JWT token'i coz ve icindeki veriyi dondur.

    Basarisizsa JWTError firlatir (token gecersiz veya suresi dolmus).
    """
    payload = jwt.decode(
        token,
        settings.SECRET_KEY,
        algorithms=[settings.ALGORITHM]
    )
    return payload
