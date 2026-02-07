# =============================================
# LOGLAMA SISTEMI
# Tum sistem olaylarini dosyaya ve konsola yazar
# =============================================
#
# 📚 DERS: Loglama nedir?
# Uygulamada olan her seyi kayit altina almak.
# print() yerine logger kullaniyoruz cunku:
# 1. Tarih/saat otomatik eklenir
# 2. Onem seviyesi belirlenebilir (INFO, WARNING, ERROR)
# 3. Dosyaya yazilir (sunucu kapansa bile kayitlar kalir)
# 4. Farkli kaynaklara yonlendirilebilir (dosya, konsol, uzak sunucu)
#
# Log seviyeleri (onem sirasina gore):
# DEBUG   -> Gelistirici icin detayli bilgi
# INFO    -> Normal islem bilgisi ("Kullanici giris yapti")
# WARNING -> Dikkat edilmesi gereken durum ("Token suresi dolmak uzere")
# ERROR   -> Hata olustu ama sistem calismaya devam ediyor
# CRITICAL-> Ciddi hata, sistem durabilir

import logging
import os
from datetime import datetime
from logging.handlers import RotatingFileHandler

from app.core.config import settings


def setup_logger(name: str = "osgb") -> logging.Logger:
    """
    📚 DERS: Logger ayarlarini yapar.

    RotatingFileHandler kullaniyoruz:
    - Dosya 5MB'i gecince yeni dosya olusturur
    - En fazla 10 dosya saklar (5MB x 10 = 50MB max)
    - Eski dosyalar otomatik silinir
    - Boylece disk dolmaz!
    """
    logger = logging.getLogger(name)

    # Zaten ayarlanmissa tekrar ayarlama
    if logger.handlers:
        return logger

    logger.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)

    # ---- LOG FORMATI ----
    # Ornek cikti:
    # 2026-02-07 19:30:45 | INFO | auth_service | Kullanici giris yapti: admin@osgbyazilim.com
    formatter = logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(name)-20s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # ---- KONSOL HANDLER ----
    # Terminalde gorunsun (gelistirme sirasinda faydali)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)
    logger.addHandler(console_handler)

    # ---- DOSYA HANDLER ----
    # Log dosyasina yaz (sunucu kapansa bile kayitlar kalir)
    log_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "logs")
    os.makedirs(log_dir, exist_ok=True)

    # Ana log dosyasi (her sey)
    file_handler = RotatingFileHandler(
        os.path.join(log_dir, "osgb.log"),
        maxBytes=5 * 1024 * 1024,  # 5 MB
        backupCount=10,             # 10 dosya sakla
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)
    file_handler.setLevel(logging.DEBUG)
    logger.addHandler(file_handler)

    # Hata log dosyasi (sadece hatalar)
    error_handler = RotatingFileHandler(
        os.path.join(log_dir, "errors.log"),
        maxBytes=5 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    error_handler.setFormatter(formatter)
    error_handler.setLevel(logging.ERROR)
    logger.addHandler(error_handler)

    return logger


# Ana logger instance'i
# Diger dosyalardan: from app.core.logger import logger
logger = setup_logger("osgb")

# Alt logger'lar (modul bazli filtreleme icin)
# Kullanim: from app.core.logger import auth_logger
# auth_logger.info("Kullanici giris yapti")
auth_logger = setup_logger("osgb.auth")
firma_logger = setup_logger("osgb.firma")
api_logger = setup_logger("osgb.api")
db_logger = setup_logger("osgb.db")
