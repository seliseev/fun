"""Общее для скриптов Google Play (gp_*.py): пакет из game.project, ключ сервисного аккаунта, токен, запросы к API.

Запуск - из корня проекта игры через обёртку: scripts/fun.sh store/<скрипт> (см. tools/README.md в FUN).

Пакет приложения - [android] package из game.project (у скриптов можно переопределить через --package).

Ключ сервисного аккаунта (JSON) скрипты ищут по порядку:
  1. переменная GOOGLE_PLAY_SERVICE_ACCOUNT_JSON - путь к JSON-файлу или сам JSON (так же, как секрет в CI);
  2. файл gp-keys.json в корне проекта (держать в .gitignore);
  3. Связка ключей macOS, запись google-play:<пакет>. Положить туда один раз (файл ключа потом можно удалить):
       security add-generic-password -U -s "google-play:<пакет>" -a "$USER" \\
         -w "$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' key.json)"
Ключ скрипты не печатают.

Зависимости: python3 + requests, подпись JWT - системный openssl.
"""

import base64
import configparser
import json
import os
import subprocess
import sys
import tempfile
import time

import requests

# Корень проекта игры: FUN_PROJECT_ROOT (ставит scripts/fun.sh) или текущая папка
ROOT = os.path.abspath(os.environ.get("FUN_PROJECT_ROOT") or os.getcwd())
API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
KEY_ENV = "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
KEY_FILE = os.path.join(ROOT, "gp-keys.json")


def get_package():
    """[android] package из game.project"""
    if not os.path.isfile(os.path.join(ROOT, "game.project")):
        sys.exit(f"Нет game.project в {ROOT}: запускайте из корня проекта (scripts/fun.sh)")
    config = configparser.ConfigParser(strict=False, interpolation=None)
    config.read(os.path.join(ROOT, "game.project"), encoding="utf-8")
    return config.get("android", "package")


def get_keychain_service(package):
    return f"google-play:{package}"


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def load_keychain_key(service):
    """JSON-ключ из Связки ключей macOS или пустая строка. security печатает пароль в hex, если в нем не только ASCII."""
    try:
        result = subprocess.run(["security", "find-generic-password", "-s", service, "-w"],
                                capture_output=True, text=True)
    except FileNotFoundError:
        return ""
    value = result.stdout.strip() if result.returncode == 0 else ""
    if value and not value.startswith("{"):
        try:
            value = bytes.fromhex(value).decode("utf-8")
        except ValueError:
            pass
    return value


def load_service_account(package):
    value = os.environ.get(KEY_ENV, "").strip()
    if not value and os.path.isfile(KEY_FILE):
        value = KEY_FILE
    service = get_keychain_service(package)
    if not value:
        value = load_keychain_key(service)
    if not value:
        sys.exit(f"Нет ключа сервисного аккаунта: ни {KEY_ENV} (путь к JSON или сам JSON), ни {KEY_FILE}, "
                 f"ни записи {service} в Связке ключей (см. tools/store/gp_common.py в FUN)")
    if not value.startswith("{"):
        with open(os.path.expanduser(value), encoding="utf-8") as fh:
            value = fh.read()
    return json.loads(value)


def get_access_token(account):
    """OAuth-токен сервисного аккаунта: JWT RS256, подпись системным openssl."""
    now = int(time.time())
    header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = b64url(json.dumps({
        "iss": account["client_email"],
        "scope": SCOPE,
        "aud": account["token_uri"],
        "iat": now,
        "exp": now + 3600,
    }).encode())
    unsigned = f"{header}.{claims}".encode()

    fd, key_path = tempfile.mkstemp(suffix=".pem")
    try:
        os.chmod(key_path, 0o600)
        with os.fdopen(fd, "w") as fh:
            fh.write(account["private_key"])
        signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=unsigned,
                                   capture_output=True, check=True).stdout
    finally:
        os.remove(key_path)

    response = requests.post(account["token_uri"], data={
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": f"{unsigned.decode()}.{b64url(signature)}",
    }, timeout=30)
    if response.status_code != 200:
        sys.exit(f"Не удалось получить токен: {response.status_code} {response.text}")
    return response.json()["access_token"]


class PlayApi:
    def __init__(self, package, token):
        self.package = package
        self.base = API.format(package=package)
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {token}"

    def request(self, method, path, **kwargs):
        response = self.session.request(method, self.base + path, timeout=60, **kwargs)
        if response.status_code >= 400:
            raise RuntimeError(f"{method} {path}: {response.status_code} {response.text}")
        return response.json() if response.text else {}
