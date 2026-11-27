#!/usr/bin/env python3
"""Сверка внутриигровых покупок игры с Google Play Console и создание недостающих.

Какие покупки нужны игре (формат данных FUN):
  assets/targets.json  -> googleplay.iapservice.products  (sku -> product id в Google Play)
  assets/gamedata.json -> iapservice.lots                 (цена usd_price, награда reward)
                       -> token.groups                    (что в награде: из нее название и описание)

Что заведено в Google Play: Google Play Developer API, monetization.onetimeproducts
(старый inappproducts для приложения закрыт: «Please migrate to the new publishing API»).
Недостающие (только с --apply) создаются с одним вариантом покупки (buy, legacyCompatible - его
видят и старые версии Play Billing), цены по регионам - пересчет usd_price от Google
(pricing:convertRegionPrices, как предлагает Play Console), затем вариант покупки активируется.
Существующие товары скрипт не меняет.

Доступ: сервисный аккаунт в Play Console (Users and permissions) с правами «Просмотр информации
о приложении», «Управление страницей приложения» и «Просмотр финансовых данных».
Ключ и пакет приложения - см. tools/store/gp_common.py в FUN.

Примеры:
  scripts/fun.sh store/gp_products           # только сверка: что есть, чего не хватает
  scripts/fun.sh store/gp_products --apply   # создать недостающие
  scripts/fun.sh store/gp_products --sync-prices  # привести цены существующих товаров к usd_price
"""

import argparse
import json
import os
import sys

from gp_common import ROOT, PlayApi, get_access_token, get_package, load_service_account

# Блок стора в assets/targets.json
TARGET = "googleplay"
LANGUAGE = "en-US"
PURCHASE_OPTION_ID = "base"
PRICE_TOLERANCE = 0.011
TITLE_MAX = 55
DESCRIPTION_MAX = 200

# Названия токенов для описаний наград
TOKEN_NAMES = {
    "gold": "gold",
    "hammer": "hammers",
    "bulb": "hints",
}


# ------------------------------------------------------------------ данные игры

def load_json(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as fh:
        return json.load(fh)


def describe_lot(lot, rewards):
    """Название и описание товара по его награде (английский, как язык по умолчанию)."""
    reward = dict(rewards.get(lot["reward"], {}))
    if "noads" in reward:
        reward.pop("noads")
        bonus = ", ".join(f"{value} {TOKEN_NAMES.get(token, token)}" for token, value in reward.items())
        description = "Removes interstitial and banner ads forever. Ads for rewards stay."
        if bonus:
            description += f" Bonus: {bonus}."
        return "No Ads Forever", description
    if list(reward) == ["gold"]:
        return f"{reward['gold']:,} Gold", f"A pack of {reward['gold']:,} gold coins."
    parts = ", ".join(f"{value} {TOKEN_NAMES.get(token, token)}" for token, value in reward.items())
    return lot["sku"], f"Contains: {parts}." if parts else lot["sku"]


def get_required_products():
    """product id -> {sku, usd_price, title, description}"""
    targets = load_json("assets/targets.json")
    gamedata = load_json("assets/gamedata.json")
    products = targets[TARGET]["iapservice"]["products"]
    lots = {lot["sku"]: lot for lot in gamedata["iapservice"]["lots"]}
    rewards = gamedata["token"]["groups"]

    required = {}
    errors = []
    for sku, product_id in products.items():
        lot = lots.get(sku)
        if not lot:
            errors.append(f"targets.json: sku {sku} нет в gamedata.json iapservice.lots")
            continue
        title, description = describe_lot(lot, rewards)
        required[product_id] = {
            "sku": sku,
            "usd_price": lot["usd_price"],
            "title": title[:TITLE_MAX],
            "description": description[:DESCRIPTION_MAX],
        }
    for sku in lots:
        if sku not in products:
            errors.append(f"gamedata.json: лот {sku} без product id в targets.json ({TARGET})")
    return required, errors


# ------------------------------------------------------------------ Google API

class ProductsApi(PlayApi):
    def list_products(self):
        products = []
        params = {"pageSize": 1000}
        while True:
            data = self.request("GET", "/oneTimeProducts", params=params)
            products += data.get("oneTimeProducts", [])
            token = data.get("nextPageToken")
            if not token:
                return products
            params["pageToken"] = token

    def convert_price(self, usd_price):
        """Цена в USD (без налога) -> цены по регионам, как их предложит Play Console."""
        units = int(usd_price)
        nanos = int(round((usd_price - units) * 1e9))
        body = {"price": {"currencyCode": "USD", "units": str(units), "nanos": nanos}}
        return self.request("POST", "/pricing:convertRegionPrices", json=body)

    def get_pricing(self, usd_price):
        """Цены варианта покупки из usd_price: (поля варианта с ценами, версия регионов, цена в США)."""
        converted = self.convert_price(usd_price)
        other = converted["convertedOtherRegionsPrice"]
        pricing = {
            "regionalPricingAndAvailabilityConfigs": [
                {"regionCode": region["regionCode"], "price": region["price"], "availability": "AVAILABLE"}
                for region in converted["convertedRegionPrices"].values()
            ],
            "newRegionsConfig": {
                "usdPrice": other["usdPrice"],
                "eurPrice": other["eurPrice"],
                "availability": "AVAILABLE",
            },
        }
        us_price = converted["convertedRegionPrices"].get("US", {}).get("price", other["usdPrice"])
        return pricing, converted["regionVersion"]["version"], us_price

    def create_product(self, product_id, info):
        """Создать товар (черновик варианта покупки) и активировать вариант покупки."""
        pricing, regions_version, us_price = self.get_pricing(info["usd_price"])
        purchase_option = {
            "purchaseOptionId": PURCHASE_OPTION_ID,
            "buyOption": {"legacyCompatible": True},
            **pricing,
        }
        body = {
            "packageName": self.package,
            "productId": product_id,
            "listings": [{"languageCode": LANGUAGE, "title": info["title"], "description": info["description"]}],
            "purchaseOptions": [purchase_option],
        }
        self.request("PATCH", f"/onetimeproducts/{product_id}", json=body, params={
            "allowMissing": "true",
            "updateMask": "listings,purchaseOptions",
            "regionsVersion.version": regions_version,
        })
        self.request("POST", f"/oneTimeProducts/{product_id}/purchaseOptions:batchUpdateStates", json={
            "requests": [{"activatePurchaseOptionRequest": {
                "packageName": self.package,
                "productId": product_id,
                "purchaseOptionId": PURCHASE_OPTION_ID,
            }}],
        })
        return us_price

    def update_prices(self, product, usd_price):
        """Пересчитать цены всех вариантов покупки товара из usd_price; остальное в товаре не меняется."""
        pricing, regions_version, us_price = self.get_pricing(usd_price)
        options = []
        for option in product.get("purchaseOptions", []):
            option = {key: value for key, value in option.items() if key != "state"}
            option.update(pricing)
            options.append(option)
        body = dict(product, purchaseOptions=options)
        self.request("PATCH", f"/onetimeproducts/{product['productId']}", json=body, params={
            "updateMask": "purchaseOptions",
            "regionsVersion.version": regions_version,
        })
        return us_price


# ------------------------------------------------------------------ вывод

def format_money(money):
    value = int(money.get("units", 0)) + int(money.get("nanos", 0)) / 1e9
    return f"{value:.2f} {money.get('currencyCode', '')}"


def money_value(money):
    return int(money.get("units", 0)) + int(money.get("nanos", 0)) / 1e9


def get_product_state(product):
    """(активен ли товар, цена в США или None): активен - если есть активный вариант покупки."""
    options = product.get("purchaseOptions", [])
    is_active = any(option.get("state") == "ACTIVE" for option in options)
    for option in options:
        for config in option.get("regionalPricingAndAvailabilityConfigs", []):
            if config.get("regionCode") == "US":
                return is_active, config["price"]
    return is_active, None


# ------------------------------------------------------------------ main

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--apply", action="store_true", help="создать недостающие товары (без флага - только сверка)")
    parser.add_argument("--sync-prices", action="store_true",
                        help="привести цены существующих товаров к usd_price из gamedata.json")
    parser.add_argument("--package", help="пакет приложения (по умолчанию - [android] package из game.project)")
    args = parser.parse_args()

    required, errors = get_required_products()
    for error in errors:
        print(f"! {error}")

    package = args.package or get_package()
    account = load_service_account(package)
    api = ProductsApi(package, get_access_token(account))
    try:
        existing = {product["productId"]: product for product in api.list_products()}
    except RuntimeError as error:
        if " 403 " in str(error):
            sys.exit(f"Нет доступа к товарам {package} у {account['client_email']}.\n"
                     "Play Console -> Users and permissions -> этот аккаунт: нужны «Просмотр информации о приложении»,\n"
                     "«Управление страницей приложения» и «Просмотр финансовых данных». Права применяются не сразу.")
        raise

    print(f"Пакет {package}: игре нужно {len(required)}, в Google Play заведено {len(existing)}\n")
    missing = []
    wrong_price = []
    for product_id, info in sorted(required.items(), key=lambda item: item[1]["sku"]):
        product = existing.get(product_id)
        if not product:
            missing.append(product_id)
            print(f"  НЕТ        {product_id:<40} {info['sku']:<16} ${info['usd_price']}  «{info['title']}»")
            continue
        is_active, price = get_product_state(product)
        # Google при пересчете округляет до .99 ($30 -> $29.99): разница в цент - не расхождение
        if price is not None and abs(money_value(price) - info["usd_price"]) > PRICE_TOLERANCE:
            wrong_price.append(product_id)
            print(f"  ЦЕНА       {product_id:<40} {info['sku']:<16} в Play {format_money(price)}, в gamedata ${info['usd_price']}")
            continue
        status = "есть      " if is_active else "НЕАКТИВЕН "
        print(f"  {status} {product_id:<40} {info['sku']:<16} {format_money(price) if price else ''}")
    for product_id in sorted(set(existing) - set(required)):
        print(f"  лишний     {product_id:<40} (в игре не используется)")

    if wrong_price and args.sync_prices:
        print(f"\nПересчитываю цены {len(wrong_price)} (все регионы - из usd_price):")
        for product_id in wrong_price:
            try:
                us = api.update_prices(existing[product_id], required[product_id]["usd_price"])
                print(f"  цена       {product_id:<40} {format_money(us)}")
            except RuntimeError as error:
                print(f"  ОШИБКА     {product_id}: {error}")
    elif wrong_price:
        print(f"\nЦена отличается у {len(wrong_price)}. Привести к gamedata.json: scripts/fun.sh store/gp_products --sync-prices")

    if not missing:
        if not wrong_price:
            print("\nВсе нужные товары заведены, цены совпадают")
        return
    if not args.apply:
        print(f"\nНе хватает {len(missing)}. Создать: scripts/fun.sh store/gp_products --apply")
        return

    print(f"\nСоздаю {len(missing)} (цены по регионам - пересчет Google из usd_price):")
    failed = 0
    for product_id in missing:
        try:
            usd = api.create_product(product_id, required[product_id])
            print(f"  создан     {product_id:<40} {format_money(usd)}")
        except RuntimeError as error:
            failed += 1
            print(f"  ОШИБКА     {product_id}: {error}")
    if failed:
        sys.exit(f"\nНе создано: {failed}")


if __name__ == "__main__":
    main()
