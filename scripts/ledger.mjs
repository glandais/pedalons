#!/usr/bin/env node
// The ledger lives in docs/ledger/<PREFIX>/<ID>.md, one file per entry (docs/ledger/README.md).
// This script generates the two indexes, docs/LEDGER_NEXT.md and docs/LEDGER_DONE.md, and checks
// what a hand edit can break. No dependency: it runs with the Node the frontend already needs.
//
//   node scripts/ledger.mjs index            regenerate both indexes
//   node scripts/ledger.mjs check            fail on a stale index, a malformed entry, a dead link,
//                                            or a code comment citing an entry that does not exist
//   node scripts/ledger.mjs next API         print the next free identifier of a prefix
//   node scripts/ledger.mjs new API "Title" [--size S] [--group "Sub-heading"] [--kind recette]
//   node scripts/ledger.mjs stale [days]     open entries not reread against the code for N days

import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const DOCS = join(ROOT, 'docs')
const LEDGER = join(DOCS, 'ledger')
const STATUSES = ['open', 'done', 'out']
const FIELDS = ['id', 'title', 'status', 'size', 'group', 'kind', 'verified', 'done']
// What an open entry waits for when no change to the code can close it.
const KINDS = {
  recette: 'À constater à la main',
  externe: "Dépend d'un tiers ou d'une opération hors du dépôt",
  decision: 'Attend une décision',
}
const DATE = /^\d{4}-\d{2}-\d{2}$/

/** The prefix table of docs/ledger/README.md: the order of the sections, and their names. */
function readPrefixes() {
  const text = readFileSync(join(LEDGER, 'README.md'), 'utf8')
  const prefixes = []
  for (const line of text.split('\n')) {
    const m = line.match(/^\| `([A-Z]+)` \| (.+?) \|$/)
    if (!m) continue
    // The index heading keeps the short name: what stands before the first comma, colon or bracket.
    const name = m[2].split(/,| : | \(/)[0].trim()
    prefixes.push({ prefix: m[1], name })
  }
  if (prefixes.length === 0) throw new Error('no prefix table in docs/ledger/README.md')
  return prefixes
}

function parseFrontmatter(text, file) {
  const m = text.match(/^---\n([\s\S]*?)\n---\n/)
  if (!m) throw new Error(`${file}: no frontmatter`)
  const data = {}
  for (const line of m[1].split('\n')) {
    if (!line.trim()) continue
    const kv = line.match(/^([a-z]+):\s*(.*?)\s*$/)
    if (!kv) throw new Error(`${file}: unreadable frontmatter line « ${line} »`)
    const [, key, raw] = kv
    if (!FIELDS.includes(key)) throw new Error(`${file}: unknown field « ${key} »`)
    // A quoted value is a JSON string (what `new` writes); anything else is taken as it stands.
    data[key] = raw.startsWith('"') ? JSON.parse(raw) : raw
  }
  return { data, body: text.slice(m[0].length) }
}

function readEntries() {
  const entries = []
  for (const dir of readdirSync(LEDGER, { withFileTypes: true })) {
    if (!dir.isDirectory()) continue
    for (const name of readdirSync(join(LEDGER, dir.name))) {
      if (name === 'README.md' || !name.endsWith('.md')) continue
      const file = join(LEDGER, dir.name, name)
      const { data, body } = parseFrontmatter(readFileSync(file, 'utf8'), relative(ROOT, file))
      entries.push({
        ...data,
        dir: dir.name,
        file,
        body,
        number: Number(name.match(/-(\d+)\.md$/)?.[1]),
      })
    }
  }
  return entries
}

const byNumberDesc = (a, b) => b.number - a.number
const link = (e) => `[\`${e.id}\`](ledger/${e.dir}/${e.id}.md)`
// A title never opens a table cell or a list item of its own in the index.
const oneLine = (s) => s.replace(/\s+/g, ' ').replace(/\|/g, '\\|')

// The size, unless the title already carries it (« … (M, backend + web) »).
const sizeSuffix = (e) => (e.size && !/\((XS|S|M|L|XL)[,) ]/.test(e.title) ? ` (${e.size})` : '')
const kindSuffix = (e) => (e.kind ? ` · *${e.kind}*` : '')

const BANNER = [
  '<!-- Généré par `node scripts/ledger.mjs index` à partir de docs/ledger/ : ne pas modifier à la main. -->',
  '',
]

function renderNext(prefixes, entries) {
  const out = ['# La suite : ce qui reste à faire', '', ...BANNER]
  const open = entries.filter((e) => e.status === 'open')
  const ruledOut = entries.filter((e) => e.status === 'out')
  const offCode = open.filter((e) => e.kind)
  out.push(
    `Index des **${open.length} entrées ouvertes** et des ${ruledOut.length} entrées écartées. Chaque entrée a son fichier`,
    'dans [`ledger/`](ledger/) ; le format, les gestes et la nomenclature sont dans',
    '[`ledger/README.md`](ledger/README.md). Ce qui est livré : [`LEDGER_DONE.md`](LEDGER_DONE.md).',
    '',
    `${offCode.length} de ces entrées ne se ferment pas par du code (*recette*, *externe*, *decision*) : elles sont`,
    'reprises [en fin de fichier](#ce-qui-ne-se-ferme-pas-par-du-code).',
    ''
  )
  for (const { prefix, name } of prefixes) {
    const mine = open.filter((e) => e.dir === prefix)
    out.push(`## ${prefix} — ${name}`, '')
    const context = existsSync(join(LEDGER, prefix, 'README.md'))
      ? ` Contexte du domaine : [\`ledger/${prefix}/README.md\`](ledger/${prefix}/README.md).`
      : ''
    if (mine.length === 0) {
      out.push(`Aucune entrée ouverte.${context}`, '')
      continue
    }
    if (context) out.push(context.trim(), '')
    const groups = new Map()
    for (const e of mine) {
      const key = e.group ?? ''
      if (!groups.has(key)) groups.set(key, [])
      groups.get(key).push(e)
    }
    const keys = [...groups.keys()].sort((a, b) =>
      a === '' ? -1 : b === '' ? 1 : a.localeCompare(b, 'fr')
    )
    for (const key of keys) {
      if (key) out.push(`### ${key}`, '')
      for (const e of groups.get(key).sort(byNumberDesc)) {
        out.push(`- [ ] ${link(e)} ${oneLine(e.title)}${sizeSuffix(e)}${kindSuffix(e)}`)
      }
      out.push('')
    }
  }
  out.push(
    '## Ce qui ne se ferme pas par du code',
    '',
    "Les mêmes entrées que plus haut, par ce qu'elles attendent : relire le code ne les fait pas avancer.",
    ''
  )
  for (const [kind, heading] of Object.entries(KINDS)) {
    const mine = offCode.filter((e) => e.kind === kind)
    if (mine.length === 0) continue
    out.push(`### ${heading} (\`${kind}\`)`, '')
    for (const { prefix } of prefixes) {
      for (const e of mine.filter((x) => x.dir === prefix).sort(byNumberDesc)) {
        out.push(`- ${link(e)} ${oneLine(e.title)}`)
      }
    }
    out.push('')
  }
  out.push(
    '## Délibérément dehors',
    '',
    "À relire avant de rouvrir l'un de ces points : chacun a été écarté avec un motif, et plusieurs",
    'sont des invariants que le code garde. Rouvert, il redevient une entrée ouverte sous le même',
    'identifiant.',
    ''
  )
  for (const { prefix } of prefixes) {
    for (const e of ruledOut.filter((x) => x.dir === prefix).sort(byNumberDesc)) {
      out.push(`- ${link(e)} ${oneLine(e.title)}`)
    }
  }
  out.push('')
  return out.join('\n')
}

function renderDone(prefixes, entries) {
  const done = entries.filter((e) => e.status === 'done')
  const partly = entries.filter((e) => e.status === 'open' && /^## Livré$/m.test(e.body))
  const out = ['# Le fait : ce qui a été livré depuis la v2', '', ...BANNER]
  out.push(
    `Index des **${done.length} entrées livrées**, et des ${partly.length} entrées encore ouvertes dont une part l'est.`,
    "Chaque entrée a son fichier dans [`ledger/`](ledger/), avec la date, la version d'API, le test qui",
    'la couvre et les décisions à ne pas défaire. Ce qui reste : [`LEDGER_NEXT.md`](LEDGER_NEXT.md).',
    ''
  )
  for (const { prefix, name } of prefixes) {
    const mine = [...done, ...partly].filter((e) => e.dir === prefix).sort(byNumberDesc)
    out.push(`## ${prefix} — ${name}`, '')
    if (mine.length === 0) out.push('Rien de livré sous ce préfixe.')
    for (const e of mine) {
      const when =
        e.status === 'done' ? (e.done ? ` — ${e.done}` : '') : ' — en partie, le reste est ouvert'
      out.push(`- [x] ${link(e)} ${oneLine(e.title)}${when}`)
    }
    out.push('')
  }
  return out.join('\n')
}

function validate(prefixes, entries) {
  const errors = []
  const known = new Set(prefixes.map((p) => p.prefix))
  const seen = new Set()
  for (const e of entries) {
    const where = relative(ROOT, e.file)
    const expected = `${e.dir}-${e.number}`
    if (e.id !== expected || !e.file.endsWith(`${expected}.md`))
      errors.push(`${where}: id « ${e.id} » does not match its path`)
    if (!known.has(e.dir))
      errors.push(`${where}: prefix ${e.dir} is not in the table of docs/ledger/README.md`)
    if (seen.has(e.id)) errors.push(`${where}: duplicate id`)
    seen.add(e.id)
    if (!e.title) errors.push(`${where}: no title`)
    if (!STATUSES.includes(e.status))
      errors.push(`${where}: status « ${e.status} » is not one of ${STATUSES.join(', ')}`)
    if (e.kind !== undefined && !(e.kind in KINDS))
      errors.push(`${where}: kind « ${e.kind} » is not one of ${Object.keys(KINDS).join(', ')}`)
    if (e.kind !== undefined && e.status !== 'open')
      errors.push(`${where}: kind only goes with an open entry`)
    for (const key of ['verified', 'done']) {
      if (e[key] !== undefined && !DATE.test(e[key]))
        errors.push(`${where}: ${key} is not a YYYY-MM-DD date`)
    }
    const section = { open: '## Reste à faire', done: '## Livré', out: '## Écarté' }[e.status]
    if (section && !e.body.split('\n').includes(section))
      errors.push(`${where}: status ${e.status} without a « ${section} » section`)
    if (e.status === 'done' && e.body.split('\n').includes('## Reste à faire'))
      errors.push(`${where}: status done but a « ## Reste à faire » section remains`)
  }
  return { errors, ids: seen }
}

/** Relative links of the ledger files and of the two indexes must lead somewhere. */
function deadLinks(files) {
  const errors = []
  for (const file of files) {
    const text = readFileSync(file, 'utf8')
    for (const m of text.matchAll(/\]\(([^)\s]+)\)/g)) {
      const target = m[1]
      if (/^(https?:|mailto:|#)/.test(target)) continue
      const path = resolve(dirname(file), decodeURI(target.split('#')[0]))
      if (!existsSync(path)) errors.push(`${relative(ROOT, file)}: dead link ${target}`)
    }
  }
  return errors
}

/** `docs/LEDGER_*.md WEB-14` in a tracked file must name an entry that exists. */
function danglingReferences(ids) {
  const out = execFileSync(
    'git',
    [
      'grep',
      '-nIoE',
      'LEDGER_[A-Z_*]+\\.md`?,? +`?[A-Z]+-[0-9]+',
      '--',
      '.',
      ':!docs/ledger',
      ':!docs/LEDGER_*.md',
    ],
    {
      cwd: ROOT,
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024,
    }
  )
  const errors = []
  for (const line of out.split('\n')) {
    const id = line.match(/([A-Z]+-[0-9]+)$/)?.[1]
    if (id && !ids.has(id))
      errors.push(
        `${line.split(':').slice(0, 2).join(':')}: cites ${id}, which is not in the ledger`
      )
  }
  return errors
}

function allLedgerFiles() {
  const files = [
    join(LEDGER, 'README.md'),
    join(DOCS, 'LEDGER_NEXT.md'),
    join(DOCS, 'LEDGER_DONE.md'),
  ]
  for (const dir of readdirSync(LEDGER, { withFileTypes: true })) {
    if (!dir.isDirectory()) continue
    for (const name of readdirSync(join(LEDGER, dir.name)))
      if (name.endsWith('.md')) files.push(join(LEDGER, dir.name, name))
  }
  return files
}

function nextId(prefix, entries) {
  const numbers = entries.filter((e) => e.dir === prefix).map((e) => e.number)
  return `${prefix}-${(numbers.length ? Math.max(...numbers) : 0) + 1}`
}

function option(args, name) {
  const i = args.indexOf(name)
  return i === -1 ? undefined : args[i + 1]
}

const today = () => new Date().toISOString().slice(0, 10)

function main() {
  const [command, ...args] = process.argv.slice(2)
  const prefixes = readPrefixes()
  const entries = readEntries()
  const targets = [
    [join(DOCS, 'LEDGER_NEXT.md'), renderNext(prefixes, entries)],
    [join(DOCS, 'LEDGER_DONE.md'), renderDone(prefixes, entries)],
  ]

  if (command === 'index') {
    for (const [file, text] of targets) writeFileSync(file, text)
    console.log(
      `${entries.length} entries: ${STATUSES.map((s) => `${entries.filter((e) => e.status === s).length} ${s}`).join(', ')}`
    )
    return
  }

  if (command === 'check') {
    const { errors, ids } = validate(prefixes, entries)
    for (const [file, text] of targets) {
      if (!existsSync(file) || readFileSync(file, 'utf8') !== text)
        errors.push(`${relative(ROOT, file)} is stale: run node scripts/ledger.mjs index`)
    }
    errors.push(...deadLinks(allLedgerFiles()), ...danglingReferences(ids))
    if (errors.length) {
      console.error(errors.join('\n'))
      console.error(`\n${errors.length} problem(s) in the ledger`)
      process.exit(1)
    }
    console.log(`ledger ok: ${entries.length} entries`)
    return
  }

  if (command === 'next' || command === 'new') {
    const prefix = args[0]
    if (!prefixes.some((p) => p.prefix === prefix))
      throw new Error(
        `unknown prefix « ${prefix} »: add it to the table of docs/ledger/README.md first`
      )
    const id = nextId(prefix, entries)
    if (command === 'next') return console.log(id)
    const title = args[1]
    if (!title || title.startsWith('--'))
      throw new Error(
        'usage: ledger.mjs new PREFIX "Title" [--size S] [--group "Sub-heading"] [--kind recette]'
      )
    const size = option(args, '--size')
    const group = option(args, '--group')
    const kind = option(args, '--kind')
    if (kind !== undefined && !(kind in KINDS))
      throw new Error(`unknown kind « ${kind} »: one of ${Object.keys(KINDS).join(', ')}`)
    const lines = ['---', `id: ${id}`, `title: ${JSON.stringify(title)}`, 'status: open']
    if (size) lines.push(`size: ${JSON.stringify(size)}`)
    if (group) lines.push(`group: ${JSON.stringify(group)}`)
    if (kind) lines.push(`kind: ${kind}`)
    lines.push(
      `verified: ${today()}`,
      '---',
      '',
      '## Reste à faire',
      '',
      `\`${id}\` **${title}** — `,
      ''
    )
    mkdirSync(join(LEDGER, prefix), { recursive: true })
    const file = join(LEDGER, prefix, `${id}.md`)
    writeFileSync(file, lines.join('\n'), { flag: 'wx' })
    console.log(relative(ROOT, file))
    return
  }

  if (command === 'stale') {
    const days = Number(args[0] ?? 30)
    const limit = new Date(Date.now() - days * 86_400_000).toISOString().slice(0, 10)
    const stale = entries.filter((e) => e.status === 'open' && (!e.verified || e.verified < limit))
    for (const e of stale.sort((a, b) => (a.verified ?? '').localeCompare(b.verified ?? ''))) {
      console.log(`${e.verified ?? 'never     '}  ${e.id}  ${e.title}`)
    }
    console.log(
      `${stale.length} open entr${stale.length === 1 ? 'y' : 'ies'} not reread since ${limit}`
    )
    return
  }

  console.error(
    'usage: node scripts/ledger.mjs index | check | next PREFIX | new PREFIX "Title" | stale [days]'
  )
  process.exit(2)
}

try {
  main()
} catch (error) {
  console.error(error.message)
  process.exit(1)
}
