// Сверка: у КАЖДОГО режима есть составной индекс.
//
//     node check-indexes.mjs
//
// Запускается из `npm run build`, то есть из predeploy-хука: выкатка падает
// здесь, до того как несвежая конфигурация уедет в облако.
//
// ── Зачем ────────────────────────────────────────────────────────────────────
// `getLeaderboard` и `weeklyReset` сортируют по двум полям сразу (score вниз,
// updated_at вверх). Такому запросу Firestore нужен ОБЪЯВЛЕННЫЙ составной
// индекс: однополевые он заводит сам, составной — нет.
//
// Коллекция здесь называется по режиму (`leaderboards/{week}/{mode}`), поэтому
// индекс нужен КАЖДОМУ режиму отдельно. Добавить режим и забыть индекс легко:
// это разные файлы, и `--only functions` второй вообще не трогает. Снаружи
// пропажа выглядит как «сервер сломался» — таблица на новой вкладке отвечает
// ошибкой, а на старых работает.
//
// Так уже было дважды: сперва файл остался на `best`/`total` после разбиения по
// режимам, потом на четырёх режимах после перехода кампании на пять эпизодов.
// Оба раза расхождение было незаметным до самого запроса.
import {readFileSync} from "node:fs";
import {fileURLToPath} from "node:url";
import {dirname, join} from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "src", "index.ts"), "utf8");
const cfg = JSON.parse(readFileSync(join(here, "..", "firestore.indexes.json"), "utf8"));

// Список режимов берётся ИЗ КОДА, а не переписывается сюда: вторая копия
// разошлась бы ровно так же, как расходится сам файл индексов.
const decl = src.match(/const MODES\s*=\s*\[([^\]]*)\]/);
if (!decl) {
  console.error("не нашёл MODES в src/index.ts — сверять не с чем");
  process.exit(1);
}
const modes = [...decl[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
if (modes.length === 0) {
  console.error("MODES пуст — сверять не с чем");
  process.exit(1);
}

const indexed = new Set((cfg.indexes ?? []).map((i) => i.collectionGroup));
const missing = modes.filter((m) => !indexed.has(m));
// Лишний индекс — не ошибка: коллекции снятых режимов остаются в базе, и их
// индексы просто никем не запрашиваются. Ошибка — только нехватка.
if (missing.length > 0) {
  console.error(
    `firestore.indexes.json отстал от MODES: нет индекса у ${missing.join(", ")}.\n` +
    "Добавьте по составному индексу (score DESC, updated_at ASC) на каждый и\n" +
    "выкатите ОТДЕЛЬНО: firebase deploy --only firestore:indexes",
  );
  process.exit(1);
}
console.log(`индексы на месте: ${modes.length} режимов`);
