#!/usr/bin/env node
// 展示页自检：静态资源 + JS 导出 + AIP 编解码语义。
// Pages self-check for gbz185.mbt.

import { readFileSync, existsSync, copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const JS_BUILD = join(ROOT, '_build/js/release/build/playground/playground.js');
const JS_DOCS = join(ROOT, 'docs/playground.js');

let failures = 0;
function check(name, ok, detail) {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? `  (${detail})` : ''}`);
  if (!ok) failures++;
}

for (const f of ['docs/index.html', 'docs/app.js', 'docs/style.css']) {
  check(`asset exists: ${f}`, existsSync(join(ROOT, f)));
}
const html = readFileSync(join(ROOT, 'docs/index.html'), 'utf8');
check('index.html mentions gbz185 + AIP', html.includes('gbz185.mbt') && html.includes('GB/Z 185'));
check('index.html loads app.js / style.css', html.includes('app.js') && html.includes('style.css'));

if (!existsSync(JS_BUILD)) {
  const r = spawnSync('moon build --target js --release playground', {
    shell: true,
    encoding: 'utf8',
    cwd: ROOT,
  });
  check('build playground js', r.status === 0, (r.stderr ?? '').slice(0, 200));
}
if (existsSync(JS_BUILD)) copyFileSync(JS_BUILD, JS_DOCS);
check('docs/playground.js exists', existsSync(JS_DOCS));
if (!existsSync(JS_DOCS)) process.exit(1);

const mod = await import('file://' + JS_DOCS.replace(/\\/g, '/'));
for (const name of ['aip_make_envelope', 'aip_validate', 'aip_fanout_count', 'aip_next_seq']) {
  check(`export: ${name}`, typeof mod[name] === 'function');
}

const env = mod.aip_make_envelope('urn:agent:a', 'urn:agent:b', 1, 1700000000, 'task_request', '{"text":"hi"}');
check('envelope has version 1 + protocol aip', env.includes('"envelope_version":"1"') && env.includes('"protocol":"aip"'));
check('envelope round-trips validation', mod.aip_validate(env) === true);
check('empty object rejected', mod.aip_validate('{}') === false);
check('unknown kind folds to error json', mod.aip_make_envelope('a', 'b', 1, 1, 'bogus', '{}').includes('"ok":false'));
check('invalid payload json folds to error', mod.aip_make_envelope('a', 'b', 1, 1, 'event', '{bad').includes('"ok":false'));
check('fanout expands 3 members', mod.aip_fanout_count(env, 'urn:agent:m1, urn:agent:m2, urn:agent:m3') === 3);
check('fanout on invalid json = -1', mod.aip_fanout_count('{}', 'a,b') === -1);
check('next_seq(41) = 42', mod.aip_next_seq(41) === 42);

console.log(`\n=== pages check: ${failures === 0 ? 'PASS' : `FAIL (${failures})`} ===`);
if (failures > 0) process.exit(1);