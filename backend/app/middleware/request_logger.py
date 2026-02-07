# =============================================
# API ISTEK LOGLAMA MIDDLEWARE
# Her API istegini otomatik olarak loglar
# =============================================
#
# 📚 DERS: Middleware nedir?
# Her istekte OTOMATIK calisan kod.
# Istek gelir -> Middleware -> Endpoint -> Middleware -> Yanit doner
#
# Bu middleware:
# 1. Istek gelince zamani kaydeder
# 2. Endpoint calisir
# 3. Yanit donunce gecen sureyi hesaplar
# 4. Her seyi loglar

import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from app.core.logger import api_logger


class RequestLoggerMiddleware(BaseHTTPMiddleware):
    """
    📚 DERS: Her HTTP istegini loglar.

    Log ornegi:
    POST /api/v1/auth/login | 200 | 0.045s | 192.168.1.9
    GET  /api/v1/firma      | 200 | 0.012s | 192.168.1.9
    POST /api/v1/firma      | 201 | 0.034s | 192.168.1.9
    GET  /api/v1/firma/999  | 404 | 0.003s | 192.168.1.9
    """

    async def dispatch(self, request: Request, call_next):
        # Baslangic zamani
        baslangic = time.time()

        # IP adresi
        ip = request.client.host if request.client else "bilinmiyor"

        # Istegi isle (endpoint calissin)
        try:
            response = await call_next(request)
        except Exception as e:
            # Beklenmeyen hata
            sure = time.time() - baslangic
            api_logger.error(
                f"{request.method:6s} {request.url.path} | 500 | {sure:.3f}s | {ip} | HATA: {e}"
            )
            raise

        # Gecen sure
        sure = time.time() - baslangic

        # Status koda gore log seviyesi
        status = response.status_code
        if status >= 500:
            api_logger.error(
                f"{request.method:6s} {request.url.path} | {status} | {sure:.3f}s | {ip}"
            )
        elif status >= 400:
            api_logger.warning(
                f"{request.method:6s} {request.url.path} | {status} | {sure:.3f}s | {ip}"
            )
        else:
            # Docs ve static dosyalari loglama (cok fazla log olur)
            if not request.url.path.startswith(("/docs", "/redoc", "/openapi.json")):
                api_logger.info(
                    f"{request.method:6s} {request.url.path} | {status} | {sure:.3f}s | {ip}"
                )

        return response
