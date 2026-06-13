# CLAUDE.md — poe2-anekeika-companion

Компаньон Path of Exile 2. Самодостаточный репозиторий (шарится с друзьями).

## Принципы
- Данные тащат скрипты (ingest/), без LLM. LLM-агент один — build-advisor.
- LLM никогда не считает урон сам: редактирует структуру билда, числа берёт у PoB2 (pob/ MCP).
- Кросс-платформа: pwsh + bash. Секреты через env. Пути через конфиг, не hardcoded.
- Личные данные (персонаж, токены) — в data/, под .gitignore. В git только код/тулинг.

## Движок
vendor/PathOfBuilding-PoE2 — сабмодуль (ветка dev). Headless через pob/headless/run_stats.lua.

## Спека / планы
docs/superpowers/specs/, docs/superpowers/plans/
