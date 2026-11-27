#!/usr/bin/env python3
"""Страница игры в Google Play: тексты, скриншоты телефона и feature graphic - сверка с локальными файлами и заливка.

Тексты: stores/googleplay/listing/<язык страницы>/ (en-US, ru-RU, ...), у каждого языка все три файла:
  title.txt              название, до 30 символов
  short_description.txt  краткое описание, до 80
  full_description.txt   полное описание, до 4000
Сравнивается текст без пробелов по краям. Видео и прочие поля страницы скрипт не трогает.

Кадры: stores/googleplay/screenshots/<язык>/<номер>_<имя>.png, порядок - по номеру. Папка кадров - язык страницы
(ru-RU) или его код без региона (ru), если в listing такой язык один. Языки страницы задают папки listing.

Feature graphic: stores/googleplay/feature_graphic.png, PNG 1024x500,
одна на все языки. Заливается в язык страницы по умолчанию (из настроек приложения в Play) - его Play показывает языкам без своей картинки.
Если у другого языка в Play своя картинка, отличная от нашей, она тоже заменяется.

Языка нет на странице в Play - скрипт добавляет его (только с --apply) со всеми тремя текстами.
Перед любым запросом к Play скрипт проверяет файлы и останавливается со списком ошибок, если чего-то не хватает:
нет папки текстов или одного из файлов, пустой файл, текст длиннее лимита, кадров меньше 2 или больше 8,
папка кадров без папки текстов, нет feature graphic или она не 1024x500. У нового языка без своих кадров Play показывает кадры языка по умолчанию.

Google Play Developer API, edits: скрипт открывает правку, сравнивает тексты и sha256 картинок в Play
с локальными и (только с --apply) обновляет отличающееся: тексты - patch листинга языка (новый язык - put),
скриншоты и feature graphic - весь набор языка (удаляет старые, загружает новые по порядку). Затем одна общая правка коммитится.
Что совпадает - не трогается. Без --apply правка удаляется, в Play ничего не меняется.

Пакет и ключ - см. tools/store/gp_common.py в FUN; у сервисного аккаунта право «Управление страницей приложения».

Примеры:
  scripts/fun.sh store/gp_listing                      # сверка текстов и скриншотов всех языков
  scripts/fun.sh store/gp_listing --apply              # залить отличающееся, добавить недостающие языки
  scripts/fun.sh store/gp_listing --apply --only texts # только тексты (или --only screenshots, --only graphic)
  scripts/fun.sh store/gp_listing --apply --lang ru-RU
  scripts/fun.sh store/gp_listing --apply --no-review  # если Play требует отправлять изменения на проверку вручную
"""

import argparse
import glob
import hashlib
import os
import sys

from gp_common import ROOT, PlayApi, get_access_token, get_package, load_service_account

UPLOAD_API = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{package}"
SHOTS_TYPE = "phoneScreenshots"
GRAPHIC_TYPE = "featureGraphic"
GRAPHIC_PATH = os.path.join(ROOT, "stores", "googleplay", "feature_graphic.png")
GRAPHIC_SIZE = (1024, 500)
SHOTS_DIR = os.path.join(ROOT, "stores", "googleplay", "screenshots")
LISTING_DIR = os.path.join(ROOT, "stores", "googleplay", "listing")
PARTS = ("texts", "screenshots", "graphic")
# Поле листинга в API -> файл и лимит Google Play
TEXT_FIELDS = {
    "title": ("title.txt", 30),
    "shortDescription": ("short_description.txt", 80),
    "fullDescription": ("full_description.txt", 4000),
}
# Ограничение Google Play на скриншоты телефона
MIN_COUNT = 2
MAX_COUNT = 8


def get_local_shots(shots_dir, lang):
    """Кадры языка по порядку: <номер>_<имя>.png"""
    files = glob.glob(os.path.join(shots_dir, lang, "[0-9]*_*.png"))
    return sorted(files, key=lambda path: int(os.path.basename(path).split("_", 1)[0]))


def load_texts(listing_dir, language, errors):
    """Тексты языка {поле API: текст}; всё, чего не хватает, - в errors"""
    folder = os.path.join(listing_dir, language)
    if not os.path.isdir(folder):
        errors.append(f"{language}: нет папки {os.path.relpath(folder, ROOT)}")
        return {}
    texts = {}
    for field, (name, limit) in TEXT_FIELDS.items():
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            errors.append(f"{language}: нет файла {name}")
            continue
        with open(path, encoding="utf-8") as fh:
            text = normalize_text(fh.read())
        if not text:
            errors.append(f"{language}: пустой {name}")
        elif len(text) > limit:
            errors.append(f"{language}: {name} - {len(text)} символов, Google Play принимает до {limit}")
        texts[field] = text
    return texts


def normalize_text(text):
    return text.replace("\r\n", "\n").strip()


def png_size(path):
    """Ширина и высота PNG по заголовку IHDR; None, если это не PNG"""
    with open(path, "rb") as fh:
        header = fh.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")


def sha256(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


class ListingApi(PlayApi):
    def __init__(self, package, token):
        super().__init__(package, token)
        self.upload_base = UPLOAD_API.format(package=package)

    def insert_edit(self):
        return self.request("POST", "/edits")["id"]

    def delete_edit(self, edit_id):
        self.request("DELETE", f"/edits/{edit_id}")

    def commit_edit(self, edit_id, is_no_review):
        params = {"changesNotSentForReview": "true"} if is_no_review else None
        self.request("POST", f"/edits/{edit_id}:commit", params=params)

    def get_listings(self, edit_id):
        """Листинги, которые уже есть на странице в Play: {язык: листинг}"""
        listings = self.request("GET", f"/edits/{edit_id}/listings").get("listings", [])
        return {listing["language"]: listing for listing in listings}

    def create_listing(self, edit_id, language, texts):
        self.request("PUT", f"/edits/{edit_id}/listings/{language}", json={"language": language, **texts})

    def update_listing(self, edit_id, language, fields):
        self.request("PATCH", f"/edits/{edit_id}/listings/{language}", json=fields)

    def get_default_language(self, edit_id):
        return self.request("GET", f"/edits/{edit_id}/details")["defaultLanguage"]

    def list_images(self, edit_id, language, image_type):
        return self.request("GET", f"/edits/{edit_id}/listings/{language}/{image_type}").get("images", [])

    def delete_images(self, edit_id, language, image_type):
        self.request("DELETE", f"/edits/{edit_id}/listings/{language}/{image_type}")

    def upload_image(self, edit_id, language, image_type, path):
        with open(path, "rb") as fh:
            data = fh.read()
        url = f"{self.upload_base}/edits/{edit_id}/listings/{language}/{image_type}"
        response = self.session.post(url, params={"uploadType": "media"}, data=data,
                                     headers={"Content-Type": "image/png"}, timeout=120)
        if response.status_code >= 400:
            raise RuntimeError(f"upload {os.path.basename(path)}: {response.status_code} {response.text}")


def get_listing_langs(listing_dir):
    """Языки страницы: папки в listing"""
    if not os.path.isdir(listing_dir):
        return []
    return sorted(name for name in os.listdir(listing_dir) if os.path.isdir(os.path.join(listing_dir, name)))


def get_shots_folders(shots_dir, langs, errors):
    """{язык страницы: папка кадров}; папка - язык страницы или его код без региона"""
    folders = {}
    if not os.path.isdir(shots_dir):
        return folders
    for name in sorted(os.listdir(shots_dir)):
        if not os.path.isdir(os.path.join(shots_dir, name)):
            continue
        matches = [lang for lang in langs if lang == name or lang.split("-")[0] == name]
        if len(matches) != 1:
            errors.append(f"кадры {name}: " + (f"подходит несколько языков текстов ({', '.join(matches)}), "
                                               "назовите папку полным языком" if matches
                                               else "нет папки текстов этого языка"))
            continue
        if matches[0] in folders:
            errors.append(f"{matches[0]}: две папки кадров ({folders[matches[0]]}, {name})")
            continue
        folders[matches[0]] = name
    return folders


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true",
                        help="залить отличающееся и добавить недостающие языки (без флага - только сверка)")
    parser.add_argument("--only", choices=PARTS, help="только тексты, скриншоты или feature graphic (по умолчанию - всё)")
    parser.add_argument("--lang", action="append",
                        help="язык страницы (ru-RU) или его код (ru); по умолчанию - все папки текстов")
    parser.add_argument("--dir", default=SHOTS_DIR, help="папка кадров (по умолчанию stores/googleplay/screenshots)")
    parser.add_argument("--graphic", default=GRAPHIC_PATH,
                        help="feature graphic (по умолчанию stores/googleplay/feature_graphic.png)")
    parser.add_argument("--listing-dir", default=LISTING_DIR,
                        help="папка текстов (по умолчанию stores/googleplay/listing)")
    parser.add_argument("--no-review", action="store_true",
                        help="коммит с changesNotSentForReview: изменения ждут ручной отправки на проверку в Play Console")
    parser.add_argument("--package", help="пакет приложения (по умолчанию - [android] package из game.project)")
    args = parser.parse_args()
    parts = [args.only] if args.only else list(PARTS)

    # Проверка локальных файлов - до любого запроса к Play
    errors = []
    all_langs = get_listing_langs(args.listing_dir)
    shots_folders = get_shots_folders(args.dir, all_langs, errors)
    langs = all_langs
    if args.lang:
        langs = []
        for name in args.lang:
            matches = [lang for lang in all_langs if lang == name or lang.split("-")[0] == name]
            if len(matches) == 1:
                langs.append(matches[0])
            else:
                errors.append(f"--lang {name}: " + (f"подходит несколько языков ({', '.join(matches)})" if matches
                                                    else "нет папки текстов этого языка"))
    texts_plan = {}
    shots_plan = {}
    for lang in langs:
        # Тексты нужны всегда: без них нельзя добавить язык
        texts_plan[lang] = load_texts(args.listing_dir, lang, errors)
        if "screenshots" in parts and lang in shots_folders:
            folder = shots_folders[lang]
            shots = get_local_shots(args.dir, folder)
            if not MIN_COUNT <= len(shots) <= MAX_COUNT:
                errors.append(f"{lang}: {len(shots)} кадров в {os.path.relpath(args.dir, ROOT)}/{folder}, "
                              f"Google Play принимает {MIN_COUNT}-{MAX_COUNT}")
            shots_plan[lang] = shots
    if "graphic" in parts:
        if not os.path.isfile(args.graphic):
            errors.append(f"feature graphic: нет файла {os.path.relpath(args.graphic, ROOT)}")
        elif png_size(args.graphic) != GRAPHIC_SIZE:
            size = png_size(args.graphic)
            errors.append(f"feature graphic: {os.path.relpath(args.graphic, ROOT)} - "
                          + (f"{size[0]}x{size[1]}" if size else "не PNG") + ", "
                          f"Google Play принимает PNG {GRAPHIC_SIZE[0]}x{GRAPHIC_SIZE[1]}")
    if errors:
        sys.exit("Не хватает данных для страницы в Play:\n  " + "\n  ".join(errors))
    if not langs:
        sys.exit(f"Нечего сверять: нет папок текстов в {os.path.relpath(args.listing_dir, ROOT)}")

    package = args.package or get_package()
    account = load_service_account(package)
    api = ListingApi(package, get_access_token(account))
    edit_id = api.insert_edit()
    is_committed = False
    try:
        listings = api.get_listings(edit_id)
        new_langs = [lang for lang in langs if lang not in listings]
        changed_texts = {}
        changed_shots = []
        changed_graphic = []
        print(f"Пакет {package}")

        if new_langs:
            print("\nНовые языки (нет на странице в Play):\n")
            for lang in new_langs:
                shots = shots_plan.get(lang)
                print(f"  ДОБАВИТЬ   {lang:<6} тексты"
                      + (f", {len(shots)} кадров" if shots else ", кадры - языка по умолчанию"))
            if args.only == "screenshots":
                sys.exit("\nНовый язык добавляется только вместе с текстами: запустите без --only screenshots")

        if "texts" in parts:
            print("\nТексты:\n")
            for lang in langs:
                if lang in new_langs:
                    continue
                language = lang
                listing = listings[language]
                diff = {field: text for field, text in texts_plan[lang].items()
                        if normalize_text(listing.get(field, "")) != text}
                if not diff:
                    print(f"  совпадает  {language}")
                    continue
                changed_texts[lang] = diff
                print(f"  ОТЛИЧАЕТСЯ {language:<6} " + ", ".join(TEXT_FIELDS[field][0] for field in diff))

        if shots_plan:
            print("\nСкриншоты телефона:\n")
            for lang, shots in shots_plan.items():
                language = lang
                remote = [] if lang in new_langs else [image.get("sha256")
                                                      for image in api.list_images(edit_id, language, SHOTS_TYPE)]
                local = [sha256(path) for path in shots]
                if remote == local:
                    print(f"  совпадает  {language:<6} {len(local)} шт.")
                    continue
                changed_shots.append(lang)
                print(f"  ОТЛИЧАЕТСЯ {language:<6} в Play {len(remote)} шт., локально {len(local)}: "
                      + ", ".join(os.path.basename(path) for path in shots))

        if "graphic" in parts:
            # Общая картинка - в языке по умолчанию; у остальных языков заменяем только свою, отличную от нашей
            default_language = api.get_default_language(edit_id)
            local = sha256(args.graphic)
            languages = sorted({lang for lang in langs if lang not in new_langs} | {default_language})
            print("\nFeature graphic:\n")
            for language in languages:
                remote = [image.get("sha256") for image in api.list_images(edit_id, language, GRAPHIC_TYPE)]
                is_default = language == default_language
                note = " (язык по умолчанию)" if is_default else ""
                if remote == [local]:
                    print(f"  совпадает  {language}{note}")
                elif not remote and not is_default:
                    print(f"  общая      {language}: своей нет, Play покажет картинку {default_language}")
                else:
                    changed_graphic.append(language)
                    print(f"  ОТЛИЧАЕТСЯ {language}{note}" + ("" if remote else ": в Play нет"))

        changed_count = len(new_langs) + len(changed_texts) + len(changed_shots) + len(changed_graphic)
        if not changed_count:
            print("\nВсё совпадает")
            return
        if not args.apply:
            print(f"\nОтличается {changed_count}. Залить: scripts/fun.sh store/gp_listing --apply")
            return

        print("\nЗаливаю:")
        for lang in new_langs:
            api.create_listing(edit_id, lang, texts_plan[lang])
            print(f"  язык       {lang:<6} добавлен")
        for lang, diff in changed_texts.items():
            api.update_listing(edit_id, lang, diff)
            print(f"  тексты     {lang:<6} " + ", ".join(TEXT_FIELDS[field][0] for field in diff))
        for lang in changed_shots:
            language = lang
            if lang not in new_langs:
                api.delete_images(edit_id, language, SHOTS_TYPE)
            for path in shots_plan[lang]:
                api.upload_image(edit_id, language, SHOTS_TYPE, path)
            print(f"  скриншоты  {language:<6} {len(shots_plan[lang])} шт.")
        for language in changed_graphic:
            api.delete_images(edit_id, language, GRAPHIC_TYPE)
            api.upload_image(edit_id, language, GRAPHIC_TYPE, args.graphic)
            print(f"  graphic    {language}")
        try:
            api.commit_edit(edit_id, args.no_review)
        except RuntimeError as error:
            if "changesNotSentForReview" in str(error):
                sys.exit("Play не отправляет изменения на проверку автоматически: повторите с --no-review "
                         "и отправьте их на проверку в Play Console (Publishing overview)")
            raise
        is_committed = True
        print("\nПравка закоммичена" + (": отправьте изменения на проверку в Play Console" if args.no_review else ""))
    except RuntimeError as error:
        if " 403 " in str(error):
            sys.exit(f"Нет доступа к странице {package} у {account['client_email']}: "
                     "нужно право «Управление страницей приложения» в Play Console")
        raise
    finally:
        if not is_committed:
            api.delete_edit(edit_id)


if __name__ == "__main__":
    main()
