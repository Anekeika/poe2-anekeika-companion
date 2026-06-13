# poe2-anekeika-companion

Компаньон Path of Exile 2 для Obsidian + Claude: данные персонажа, торговли, меты
и советы по замене предметов на базе расчёта Path of Building 2.

## Установка

Требуется LuaJIT в PATH и git.

```
# Windows
pwsh scripts/install.ps1
# Linux/macOS
bash scripts/install.sh
```

Скрипт проверит luajit и инициализирует движок PoB2 (vendor/PathOfBuilding-PoE2).

## Спайк PoB2 (проверка движка)

```
pwsh scripts/spike-pob2.ps1    # или: bash scripts/spike-pob2.sh
```

Грузит фикстуру персонажа в headless-PoB2 и печатает DPS/EHP.

## Статус

MVP в разработке. См. docs/superpowers/specs/.
