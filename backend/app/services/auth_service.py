# =============================================
# AUTH SERVICE (Kimlik Dogrulama Servisi)
# Giris/cikis is mantigi burada
# =============================================

# 📚 DERS: Service Katmani Nedir?
# API endpoint -> Service -> Database
#
# Endpoint: HTTP istegini alir (POST /login)
# Service:  Is mantigini yapar (sifre kontrol, token olustur)
# Database: Veriyi okur/yazar
#
# Neden ayiriyoruz?
# - Kod tekrari onlenir (ayni mantik baska yerlerde de kullanilabilir)
# - Test yazmasi kolay olur
# - Kod daha okunabilir olur

from datetime import datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.models.master import Kullanici, Tenant
from app.core.security import sifre_dogrula, token_olustur
from app.schemas.auth import KullaniciBilgi, TokenResponse


def kullanici_giris(email: str, sifre: str, db: Session) -> TokenResponse:
    """
    📚 DERS: Kullanici giris islemi.

    Adimlar:
    1. Email ile kullaniciyi bul
    2. Sifre dogru mu kontrol et
    3. Kullanici aktif mi kontrol et
    4. JWT token olustur
    5. Token + kullanici bilgilerini dondur

    Herhangi bir adimda hata olursa HTTPException firlatir.
    """

    # ---- 1. KULLANICIYI BUL ----
    kullanici = db.query(Kullanici).filter(
        Kullanici.email == email
    ).first()
    # .filter() = SQL'deki WHERE
    # .first()  = Ilk sonucu getir (ya da None)

    if not kullanici:
        # 📚 DERS: Guvenlik icin "email bulunamadi" DEMIYORUZ.
        # Saldirganlar hangi emaillerin kayitli oldugunu ogrenmesin.
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya sifre hatali",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # ---- 2. SIFRE KONTROL ----
    if not sifre_dogrula(sifre, kullanici.sifre_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email veya sifre hatali",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # ---- 3. AKTIFLIK KONTROL ----
    if not kullanici.aktif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesabiniz devre disi birakilmis",
        )

    # ---- 4. TENANT BILGISI ----
    # Sistem admin icin tenant yok (null)
    # OSGB kullanicilari icin tenant bilgisi lazim
    tenant_ad = None
    db_name = None

    if kullanici.tenant_id:
        tenant = db.query(Tenant).filter(
            Tenant.id == kullanici.tenant_id
        ).first()
        if tenant:
            tenant_ad = tenant.ad
            db_name = tenant.db_name

    # ---- 5. JWT TOKEN OLUSTUR ----
    # Token icine koyacagimiz bilgiler
    token_verisi = {
        "sub": kullanici.email,           # sub = subject (kim?)
        "user_id": kullanici.id,
        "rol": kullanici.rol.value,       # .value: Enum'un string degeri
        "tenant_id": kullanici.tenant_id,
        "db_name": db_name,
    }
    access_token = token_olustur(token_verisi)

    # ---- 6. SON GIRIS TARIHINI GUNCELLE ----
    kullanici.son_giris = datetime.utcnow()
    db.commit()

    # ---- 7. YANIT OLUSTUR ----
    kullanici_bilgi = KullaniciBilgi(
        id=kullanici.id,
        email=kullanici.email,
        ad=kullanici.ad,
        soyad=kullanici.soyad,
        rol=kullanici.rol.value,
        tenant_id=kullanici.tenant_id,
        tenant_ad=tenant_ad,
        db_name=db_name,
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        kullanici=kullanici_bilgi,
    )
