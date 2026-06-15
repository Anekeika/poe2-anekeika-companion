# План 2 — Персонаж → реальные числа → дашборд (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Из персонажа Павла получить реальные статы (DPS / выживание / резисты) через движок PoB2 в WSL и показать их красивой Obsidian-заметкой. Источник персонажа — pluggable: manual-импорт работает сразу, public-OAuth подключается, когда GGG одобрит регистрацию.

**Architecture:** `ingest/` нормализует персонажа (items JSON + passives JSON) в `data/character/<name>/`. Расчёт — **one-shot** вызов движка PoB2 в WSL (`run_stats.lua` через `loadBuildFromJSON`), выдаёт полный стат-блок JSON. `dashboard/` рендерит из него Obsidian-заметку. Долгоживущий stdio-MCP-мост — НЕ здесь (Plan 3, советчик).

**Tech Stack:** Node.js (ingest/renderer/glue), LuaJIT в WSL (движок), PowerShell Core + bash (обёртки WSL), git.

**Зависимости (добавить в install):** Node.js ≥ 20 (нативная часть), WSL-рантайм из Плана 1 (`install-wsl.sh`).

**Pluggable-источник — два impl одного интерфейса `getCharacter() -> {items, passives, meta}`:**
- **manual** (Task 2): пользователь даёт PoB-код или два JSON → нормализуем в store. Работает день 1.
- **oauth** (Task 7): public client GGG (PKCE) → `GET /character/poe2/<name>`. Подключается, если регистрация прошла (Task 1 выясняет эмпирически).

**Связь:** спека `docs/superpowers/specs/2026-06-13-companion-mvp-design.md`; гейт `docs/superpowers/spike-pob2-result.md`.

---

## File Structure (создаётся этим планом)

```
poe2-anekeika-companion/
├─ package.json                      Node-проект (тип module), скрипты
├─ src/
│  ├─ ingest/
│  │  ├─ source.js                   интерфейс getCharacter() + выбор impl
│  │  ├─ manual.js                   manual-источник (PoB-код / JSON -> normalized)
│  │  ├─ oauth.js                    public-OAuth источник (PKCE) [Task 7]
│  │  └─ store.js                    запись/чтение data/character/<name>/
│  ├─ pob/
│  │  └─ run-stats.js                Node-обёртка: зовёт движок в WSL, парсит статы
│  ├─ dashboard/
│  │  └─ render.js                   stats JSON -> Obsidian markdown
│  └─ refresh.js                     glue: source -> store -> stats -> dashboard
├─ pob/headless/run_stats.lua        РАСШИРИТЬ: полный стат-блок (Task 3)
├─ scripts/
│  ├─ pob-stats.sh                   WSL-сторона one-shot расчёта (Task 4)
│  └─ poe2-refresh.ps1               Windows-точка входа -> node src/refresh.js
├─ data/character/<name>/            (gitignored) latest.json + history
└─ dashboard/out/character.md        (gitignored) сгенерированная заметка
```

**Тестирование:** Node-части тестируем через `node --test` (встроенный тест-раннер, без внешних зависимостей). Чистые функции (нормализация, рендер) — обычный TDD. Расчёт в WSL и OAuth-регистрация — спайк-проверки с критериями (как в Плане 1), не мок.

---

## Task 1: Эмпирически выяснить — регистрация public-клиента GGG instant или gated?

**Files:** Create: `docs/superpowers/oauth-registration-note.md`

Это investigation-задача (узнать факт), не код.

- [ ] **Step 1: Открыть страницу приложений GGG**

Зайти залогиненным на `https://www.pathofexile.com/my-account/applications`. Проверить: есть ли self-serve кнопка «создать приложение/client» для public-клиента, или форма-заявка / требование писать в GGG.

- [ ] **Step 2: Зафиксировать вывод в `oauth-registration-note.md`**

Записать одно из:
- **instant:** есть self-serve → получен `client_id`, redirect URI `http://127.0.0.1:8765/callback`, scope `account:characters`. → Task 7 делаем в этом плане.
- **gated:** нужна заявка/письмо → отправлено (дата), `client_id` ждём. → Task 7 помечаем deferred, План 2 завершается на manual-источнике.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/oauth-registration-note.md
git commit -m "docs(oauth): зафиксирован способ регистрации public-клиента GGG"
```

---

## Task 2: Manual-источник + store

**Files:**
- Create: `package.json`, `src/ingest/store.js`, `src/ingest/manual.js`, `src/ingest/source.js`
- Test: `src/ingest/manual.test.js`, `src/ingest/store.test.js`

Нормализованный персонаж: `{ name, class, level, items, passives, source }`, где `items`/`passives` — JSON-строки в формате, который ест `loadBuildFromJSON` (= ответы legacy `get-items` / `get-passive-skills`).

- [ ] **Step 1: `package.json`**

```json
{
  "name": "poe2-anekeika-companion",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "test": "node --test",
    "refresh": "node src/refresh.js"
  },
  "engines": { "node": ">=20" }
}
```

- [ ] **Step 2: Failing-тест store**

`src/ingest/store.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { saveCharacter, loadLatest } from './store.js';
import { rmSync } from 'node:fs';

test('saveCharacter then loadLatest round-trips', () => {
  const ch = { name: 'TestChar', class: 'Ranger', level: 90, items: '{"items":[]}', passives: '{"hashes":[]}', source: 'manual' };
  saveCharacter(ch, 'data/_test');
  const got = loadLatest('TestChar', 'data/_test');
  assert.equal(got.name, 'TestChar');
  assert.equal(got.level, 90);
  rmSync('data/_test', { recursive: true, force: true });
});
```

- [ ] **Step 3: Запустить — упадёт**

Run: `node --test src/ingest/store.test.js`
Expected: FAIL (`store.js` не существует).

- [ ] **Step 4: `src/ingest/store.js`**

```js
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export function saveCharacter(ch, root = 'data/character') {
  const dir = join(root, ch.name);
  mkdirSync(dir, { recursive: true });
  const payload = JSON.stringify(ch, null, 2);
  writeFileSync(join(dir, 'latest.json'), payload);
  return join(dir, 'latest.json');
}

export function loadLatest(name, root = 'data/character') {
  const p = join(root, name, 'latest.json');
  return JSON.parse(readFileSync(p, 'utf8'));
}
```

- [ ] **Step 5: Тест проходит**

Run: `node --test src/ingest/store.test.js`
Expected: PASS.

- [ ] **Step 6: Failing-тест manual (PoB-код -> normalized)**

`src/ingest/manual.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fromItemsPassives } from './manual.js';

test('fromItemsPassives builds normalized character', () => {
  const items = JSON.stringify({ character: { name: 'Ane', class: 'Deadeye', level: 92 }, items: [] });
  const passives = JSON.stringify({ hashes: [1,2,3] });
  const ch = fromItemsPassives(items, passives);
  assert.equal(ch.name, 'Ane');
  assert.equal(ch.class, 'Deadeye');
  assert.equal(ch.level, 92);
  assert.equal(ch.source, 'manual');
  assert.equal(typeof ch.items, 'string');
});
```

- [ ] **Step 7: Запустить — упадёт**

Run: `node --test src/ingest/manual.test.js`
Expected: FAIL.

- [ ] **Step 8: `src/ingest/manual.js`**

```js
// Принимает два JSON (get-items / get-passive-skills формат) -> normalized.
export function fromItemsPassives(itemsJSON, passivesJSON) {
  const items = JSON.parse(itemsJSON);
  const c = items.character || {};
  return {
    name: c.name ?? 'Unknown',
    class: c.class ?? 'Unknown',
    level: c.level ?? 0,
    items: itemsJSON,
    passives: passivesJSON,
    source: 'manual',
  };
}
```

- [ ] **Step 9: Тест проходит**

Run: `node --test src/ingest/manual.test.js`
Expected: PASS.

- [ ] **Step 10: `src/ingest/source.js`** (интерфейс + выбор impl)

```js
import { fromItemsPassives } from './manual.js';

// Возвращает normalized character. По умолчанию manual из двух файлов.
export async function getCharacter(opts) {
  if (opts.source === 'manual') {
    const { readFileSync } = await import('node:fs');
    return fromItemsPassives(
      readFileSync(opts.itemsPath, 'utf8'),
      readFileSync(opts.passivesPath, 'utf8'),
    );
  }
  if (opts.source === 'oauth') {
    const { fetchCharacter } = await import('./oauth.js');
    return fetchCharacter(opts.characterName); // [Task 7]
  }
  throw new Error(`unknown source: ${opts.source}`);
}
```

- [ ] **Step 11: Commit**

```bash
git add package.json src/ingest
git commit -m "feat(ingest): manual source + store с тестами"
```

---

## Task 3: Расширить `run_stats.lua` до полного стат-блока

**Files:** Modify: `pob/headless/run_stats.lua`

Текущая версия печатает TotalDPS/Life/ES/Mana. Дашборду нужны ещё резисты, имя/класс/уровень. Реальные ключи `output` подтверждаем в WSL.

- [ ] **Step 1: Discovery — перечислить доступные ключи `output`**

В WSL, на реальной фикстуре (фикстуру положить в `pob/fixtures/sample.{items,passives}.json` — взять свой персонаж через manual-экспорт PoB/pobb.in):
```bash
cd vendor/PathOfBuilding-PoE2/src
LUA_PATH='../runtime/lua/?.lua;../runtime/lua/?/init.lua' luajit -e '
dofile("HeadlessWrapper.lua")
loadBuildFromJSON(io.open("'$PWD'/../../../pob/fixtures/sample.items.json"):read("*a"), io.open("'$PWD'/../../../pob/fixtures/sample.passives.json"):read("*a"))
local o = mainObject.main.modes["BUILD"].output
for k,v in pairs(o) do if type(v)=="number" then print(k, v) end end
' < /dev/null | sort | grep -iE 'dps|life|energy|resist|mana|evasion|armour|block'
```
Записать реальные ключи (ожидаемо: `TotalDPS`, `Life`, `EnergyShield`, `Mana`, `FireResist`, `ColdResist`, `LightningResist`, `ChaosResist`, `Armour`, `Evasion`).

- [ ] **Step 2: Обновить `run_stats.lua` под подтверждённые ключи**

```lua
-- Usage: luajit run_stats.lua <items.json> <passives.json>
-- cwd должен быть <engine>/src. stdin = /dev/null (иначе висит на ошибке).
local itemsPath    = assert(arg[1], "arg1: items JSON")
local passivesPath = assert(arg[2], "arg2: passives JSON")
local function readFile(p) local f=assert(io.open(p,"r")); local s=f:read("*a"); f:close(); return s end

dofile("HeadlessWrapper.lua")
loadBuildFromJSON(readFile(itemsPath), readFile(passivesPath))
local build = mainObject.main.modes["BUILD"]
local o = build.output
local function n(k) return o[k] or 0 end

-- имя/класс/уровень из загруженного билда
local spec = build.spec
local name  = (build.dbFileName) or "Unknown"
local level = build.characterLevel or n("Level")
local class = (spec and spec.curClassName) or "Unknown"
local ascend = (spec and spec.curAscendClassName) or ""

-- ВАЖНО: ключи из Step 1; поправить, если отличаются
io.write(string.format(
  '{"name":%q,"class":%q,"ascendancy":%q,"level":%s,'..
  '"TotalDPS":%s,"Life":%s,"EnergyShield":%s,"Mana":%s,'..
  '"FireResist":%s,"ColdResist":%s,"LightningResist":%s,"ChaosResist":%s,'..
  '"Armour":%s,"Evasion":%s}',
  name, class, ascend, tostring(level),
  tostring(n("TotalDPS")), tostring(n("Life")), tostring(n("EnergyShield")), tostring(n("Mana")),
  tostring(n("FireResist")), tostring(n("ColdResist")), tostring(n("LightningResist")), tostring(n("ChaosResist")),
  tostring(n("Armour")), tostring(n("Evasion"))
))
```

- [ ] **Step 3: Проверить вывод в WSL**

Run (из репо):
```bash
cd vendor/PathOfBuilding-PoE2/src && LUA_PATH='../runtime/lua/?.lua;../runtime/lua/?/init.lua' luajit ../../../pob/headless/run_stats.lua ../../../pob/fixtures/sample.items.json ../../../pob/fixtures/sample.passives.json < /dev/null
```
Expected: одна строка валидного JSON, `TotalDPS` > 0, корректные имя/класс/уровень.

- [ ] **Step 4: Commit**

```bash
git add pob/headless/run_stats.lua
git commit -m "feat(pob): run_stats выдаёт полный стат-блок (dps/выживание/резисты/идентичность)"
```

---

## Task 4: WSL-сторона one-shot расчёта + Node-обёртка

**Files:**
- Create: `scripts/pob-stats.sh`, `src/pob/run-stats.js`
- Test: `src/pob/run-stats.test.js`

- [ ] **Step 1: `scripts/pob-stats.sh`** (запускается ВНУТРИ WSL; принимает абс. пути к двум JSON, печатает статы)

```bash
#!/usr/bin/env bash
# Usage (в WSL): bash scripts/pob-stats.sh <items.json> <passives.json>
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
items="$1"; passives="$2"
cd "$root/vendor/PathOfBuilding-PoE2/src"
LUA_PATH='../runtime/lua/?.lua;../runtime/lua/?/init.lua' \
  luajit "$root/pob/headless/run_stats.lua" "$items" "$passives" < /dev/null
```

- [ ] **Step 2: `src/pob/run-stats.js`** (Node на Windows: пишет временные JSON, зовёт WSL, парсит статы)

```js
import { writeFileSync, mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { execFileSync } from 'node:child_process';

// character: normalized {items, passives}. Возвращает объект статов.
export function computeStats(character, repoRoot = '.') {
  const tmp = mkdtempSync(join(tmpdir(), 'pob-'));
  const itemsP = join(tmp, 'items.json');
  const passivesP = join(tmp, 'passives.json');
  writeFileSync(itemsP, character.items);
  writeFileSync(passivesP, character.passives);

  const toWsl = (p) => execFileSync('wsl', ['wslpath', '-a', p]).toString().trim();
  const shWsl = toWsl(join(repoRoot, 'scripts/pob-stats.sh'));
  const out = execFileSync('wsl', ['-e', 'bash', shWsl, toWsl(itemsP), toWsl(passivesP)], {
    encoding: 'utf8', maxBuffer: 10 * 1024 * 1024,
  });
  const line = out.trim().split('\n').filter(l => l.startsWith('{')).pop();
  return JSON.parse(line);
}
```

- [ ] **Step 3: Интеграционный тест (нужен WSL + фикстура)**

`src/pob/run-stats.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { computeStats } from './run-stats.js';

test('computeStats возвращает положительный DPS на фикстуре', { skip: !existsSync('pob/fixtures/sample.items.json') }, () => {
  const character = {
    items: readFileSync('pob/fixtures/sample.items.json', 'utf8'),
    passives: readFileSync('pob/fixtures/sample.passives.json', 'utf8'),
  };
  const s = computeStats(character, '.');
  assert.ok(s.TotalDPS > 0, 'TotalDPS должен быть > 0');
  assert.ok(s.Life > 0 || s.EnergyShield > 0, 'есть пул здоровья');
});
```

- [ ] **Step 4: Запустить**

Run: `node --test src/pob/run-stats.test.js`
Expected: PASS (или SKIP, если фикстуры нет — тогда положить фикстуру и повторить).

- [ ] **Step 5: Commit**

```bash
git add scripts/pob-stats.sh src/pob/run-stats.js src/pob/run-stats.test.js
git commit -m "feat(pob): one-shot расчёт статов через WSL + Node-обёртка"
```

---

## Task 5: Рендер дашборда (stats -> Obsidian markdown)

**Files:**
- Create: `src/dashboard/render.js`
- Test: `src/dashboard/render.test.js`

- [ ] **Step 1: Failing-тест**

`src/dashboard/render.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderCharacter } from './render.js';

test('renderCharacter включает имя, DPS и резисты', () => {
  const md = renderCharacter({
    name: 'Ane', class: 'Deadeye', ascendancy: 'Deadeye', level: 92,
    TotalDPS: 1234567, Life: 4200, EnergyShield: 0, Mana: 120,
    FireResist: 75, ColdResist: 76, LightningResist: 75, ChaosResist: -20,
    Armour: 1000, Evasion: 9000,
  }, '2026-06-13 12:00');
  assert.match(md, /Ane/);
  assert.match(md, /Deadeye/);
  assert.match(md, /1\.23M|1234567|1 234 567/);
  assert.match(md, /Fire/);
  assert.match(md, /-20/);
});
```

- [ ] **Step 2: Запустить — упадёт**

Run: `node --test src/dashboard/render.test.js`
Expected: FAIL.

- [ ] **Step 3: `src/dashboard/render.js`**

```js
function fmt(n) {
  if (n >= 1e6) return (n / 1e6).toFixed(2) + 'M';
  if (n >= 1e3) return (n / 1e3).toFixed(1) + 'k';
  return String(Math.round(n));
}

export function renderCharacter(s, when) {
  const hp = s.EnergyShield > 0 ? `${s.Life} life / ${s.EnergyShield} ES` : `${s.Life} life`;
  return `# ${s.name} — ${s.ascendancy || s.class} (ур. ${s.level})

> Обновлено: ${when}

## Урон и выживание

| Метрика | Значение |
|---|---|
| **Total DPS** | **${fmt(s.TotalDPS)}** |
| Пул HP | ${hp} |
| Mana | ${s.Mana} |
| Armour / Evasion | ${fmt(s.Armour)} / ${fmt(s.Evasion)} |

## Резисты

| Fire | Cold | Lightning | Chaos |
|---|---|---|---|
| ${s.FireResist}% | ${s.ColdResist}% | ${s.LightningResist}% | ${s.ChaosResist}% |
`;
}
```

- [ ] **Step 4: Тест проходит**

Run: `node --test src/dashboard/render.test.js`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/dashboard/render.js src/dashboard/render.test.js
git commit -m "feat(dashboard): рендер заметки персонажа из статов"
```

---

## Task 6: Glue `refresh.js` + точка входа `/poe2-refresh`

**Files:**
- Create: `src/refresh.js`, `scripts/poe2-refresh.ps1`

- [ ] **Step 1: `src/refresh.js`** (source -> store -> stats -> dashboard)

```js
import { getCharacter } from './ingest/source.js';
import { saveCharacter } from './ingest/store.js';
import { computeStats } from './pob/run-stats.js';
import { renderCharacter } from './dashboard/render.js';
import { mkdirSync, writeFileSync } from 'node:fs';

// Аргументы (manual): --items <path> --passives <path>
function arg(name) { const i = process.argv.indexOf(name); return i >= 0 ? process.argv[i+1] : undefined; }

const character = await getCharacter({
  source: arg('--source') || 'manual',
  itemsPath: arg('--items'),
  passivesPath: arg('--passives'),
  characterName: arg('--character'),
});
saveCharacter(character);
const stats = computeStats(character, '.');
const when = new Date().toISOString().replace('T', ' ').slice(0, 16);
const md = renderCharacter({ ...stats, name: stats.name || character.name }, when);
mkdirSync('dashboard/out', { recursive: true });
writeFileSync('dashboard/out/character.md', md);
console.log(`[ok] ${character.name}: DPS ${stats.TotalDPS} -> dashboard/out/character.md`);
```

- [ ] **Step 2: `scripts/poe2-refresh.ps1`** (Windows-точка входа)

```powershell
#Requires -Version 7
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try { node src/refresh.js @args } finally { Pop-Location }
```

- [ ] **Step 3: Прогон end-to-end (нужна фикстура + WSL)**

Run: `pwsh scripts/poe2-refresh.ps1 --items pob/fixtures/sample.items.json --passives pob/fixtures/sample.passives.json`
Expected: `[ok] <имя>: DPS <число> -> dashboard/out/character.md`; заметка открывается в Obsidian, числа правдоподобны.

- [ ] **Step 4: Commit**

```bash
git add src/refresh.js scripts/poe2-refresh.ps1
git commit -m "feat: /poe2-refresh — персонаж в реальный дашборд (manual-источник)"
```

---

## Task 7: Public-OAuth источник (УСЛОВНО — если Task 1 = instant)

**Files:**
- Create: `src/ingest/oauth.js`
- Test: `src/ingest/oauth.test.js`

> Если Task 1 показал **gated** — пропустить, пометить в `oauth-registration-note.md` как deferred-follow-up. Manual-источник из Task 2–6 — рабочий MVP. Если **instant** — делаем.

- [ ] **Step 1: PKCE-флоу — генерация verifier/challenge + локальный редирект**

`src/ingest/oauth.js` (скелет; `CLIENT_ID` из Task 1, redirect `http://127.0.0.1:8765/callback`):
```js
import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';

const CLIENT_ID = process.env.POE_CLIENT_ID; // из Task 1
const REDIRECT = 'http://127.0.0.1:8765/callback';
const AUTH = 'https://www.pathofexile.com/oauth/authorize';
const TOKEN = 'https://www.pathofexile.com/oauth/token';

function pkce() {
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  return { verifier, challenge };
}

export function buildAuthUrl(challenge, state) {
  const p = new URLSearchParams({
    client_id: CLIENT_ID, response_type: 'code', scope: 'account:characters',
    state, redirect_uri: REDIRECT, code_challenge: challenge, code_challenge_method: 'S256',
  });
  return `${AUTH}?${p}`;
}
// captureCode(): поднять http-сервер на 8765, открыть buildAuthUrl в браузере,
// дождаться ?code=...&state=..., вернуть code. (реализация в Step 3)
```

- [ ] **Step 2: Тест PKCE (чистая часть)**

`src/ingest/oauth.test.js`:
```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildAuthUrl } from './oauth.js';

test('buildAuthUrl содержит PKCE и нужный scope', () => {
  process.env.POE_CLIENT_ID = 'test-client';
  const url = buildAuthUrl('chal123', 'state123');
  assert.match(url, /code_challenge=chal123/);
  assert.match(url, /code_challenge_method=S256/);
  assert.match(url, /scope=account%3Acharacters/);
});
```
Run: `node --test src/ingest/oauth.test.js` → PASS.

- [ ] **Step 3: Полный флоу + обмен кода на токен + fetch персонажа**

Дописать в `oauth.js`: локальный http-сервер ловит `code`; POST на `TOKEN` (grant_type=authorization_code, code_verifier) → access+refresh; refresh сохраняем в `data/.token.json` (под .gitignore); `fetchCharacter(name)` → `GET https://api.pathofexile.com/character/poe2/<name>` с `Authorization: Bearer` → разложить ответ на `items`/`passives` в normalized-формат (тот же, что ест `loadBuildFromJSON`). Реализовать refresh-flow (токен живёт 7 дней).

- [ ] **Step 4: Живой прогон**

Run: `pwsh scripts/poe2-refresh.ps1 --source oauth --character <ИмяПерсонажа>`
Expected: открывается браузер для авторизации (один раз), затем `[ok] ...` с реальными числами. Повторный запуск в течение 7 дней — без браузера (refresh-токен).

- [ ] **Step 5: Commit**

```bash
git add src/ingest/oauth.js src/ingest/oauth.test.js
git commit -m "feat(ingest): public-OAuth источник (PKCE) для живого fetch персонажа"
```

---

## Self-Review (против спеки и цели)

**Покрытие:**
- Pluggable источник (manual + oauth) → Task 2 (интерфейс) + Task 7 ✅
- Расчёт реальных статов через PoB2 в WSL (one-shot) → Task 3, 4 ✅
- Дашборд-блок персонажа → Task 5, 6 ✅
- OAuth public client + риск регистрации → Task 1 (эмпирика) + Task 7 (условно) ✅
- Приватность: `data/`, токен, фикстуры, `dashboard/out/` — под .gitignore (из Плана 1) ✅

**Сознательно вне плана (дальше):** долгоживущий stdio-MCP-мост + агент-советчик (Plan 3); мета/курсы из форка sergeyklay в дашборд (Plan 3); trade2 (Plan 4).

**Placeholder-скан:** ключи `output` в Task 3 помечены «подтвердить в Step 1» — это discovery с конкретной командой, не заглушка. Task 7 условный — критерий условия явный (Task 1).

**Согласованность имён:** `getCharacter()` → normalized `{name,class,level,items,passives,source}` един во всех задачах; `computeStats(character, repoRoot)` → объект статов с ключами, которые `renderCharacter(s)` потребляет (TotalDPS, Life, EnergyShield, Mana, *Resist, Armour, Evasion) — совпадает между Task 3/4/5.

**Зависимости-предусловия:** Node ≥20 (нативно), WSL-рантайм (`install-wsl.sh` из Плана 1), фикстура `pob/fixtures/sample.{items,passives}.json` для интеграционных тестов (Task 3+).
