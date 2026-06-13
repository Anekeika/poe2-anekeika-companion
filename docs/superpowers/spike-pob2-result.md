# Спайк №1 — результат: ЗЕЛЁНЫЙ ✅

**Дата:** 2026-06-13
**Вопрос гейта (спека §7):** заводится ли headless-движок PoB2 и считает ли реальные DPS/EHP для PoE 2.
**Вердикт:** да. Движок PoB2 (форк `PathOfBuilding-PoE2 @ dev`) запускается headless и корректно считает статы билдов PoE 2 (0.5).

## Доказательство

Штатные расчётные spec'и форка (то, что гоняет его зелёный CI), запущены локально:

| Spec | Покрытие | Результат |
|---|---|---|
| `TestDefence_spec` | выживание (life/ES/резисты/митигейшн) | 8 / 0 |
| `TestAttacks_spec` | DPS атак | 13 / 0 |
| `TestSkills_spec` | скиллы/DPS | 46 / 0 |

67 ассертов, 0 провалов. Движок грузит дерево пассивок версии `0_5`, uniques/rares.

## Рантайм (важно): движок живёт в Linux, не на голом Windows

Под Windows boot упёрся в нативные C-модули (`lua-utf8`, потенциально `lcurl`/json) — ABI-несовместимость с winget-luajit. **Решение: движок гоняем в WSL/Ubuntu** (среда, в которой форк и тестируется). Это поправка к спеке §6/§11: модуль `pob/` работает в Linux-рантайме (WSL сейчас; Docker-образ форка для шеринга позже). Остальное (ingest/store/dashboard/advisor) — нативное кросс-платформенное.

## Что понадобилось (воспроизводимо)

1. **WSL Ubuntu 24.04**, root через `wsl -u root` (без пароля).
2. **DNS-фикс** (WSL NAT-резолвер мигал): `printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf`.
3. **Зависимости** (`scripts/install-wsl.sh`): `luajit libluajit-5.1-dev lua5.1 liblua5.1-0-dev luarocks build-essential unzip` + `luarocks --lua-version=5.1 install luautf8`.
4. **busted** (для прогона spec'ов): `luarocks install busted`.

## Грабли (для будущего)

- **stdin-затык:** на ошибке PoB ждёт «Press Enter» → headless висит на блокирующем read. Фикс: запускать со stdin из `/dev/null` (EOF).
- **LUA_PATH перезапись:** если задаёшь свой `LUA_PATH`, добавляй `;;` в конец, иначе теряются дефолтные пути (busted и пр. не находятся).
- **busted звать из КОРНЯ репо движка** (не из `src`): там `.busted`-конфиг сам ставит `lpath`, `directory=src` и грузит `HeadlessWrapper.lua` как helper (даёт глобали `newBuild` и т.д.).
- **`missing node NNNN`** при загрузке дерева — нефатально (мелкие расхождения данных дерева в EA).

## Команда-проверка гейта

```bash
cd vendor/PathOfBuilding-PoE2 && busted --lua=luajit ../spec/System/TestDefence_spec.lua
```
(обёрнуто в `scripts/spike-pob2.sh`)
