#!/usr/bin/env node
// 展示页自检：静态结构 + 钩子 + JS 导出 + AIP 编解码/匹配语义 + 口径一致性。
// Pages self-check for gbz185.mbt (structure, hooks, exports, semantics, numbers).

import { readFileSync, existsSync, copyFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const JS_BUILD = join(ROOT, '_build/js/release/build/playground/playground.js');
const JS_DOCS = join(ROOT, 'docs/playground.js');

let failures = 0;
let total = 0;
function check(name, ok, detail) {
  total++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? `  (${detail})` : ''}`);
  if (!ok) failures++;
}

/* ---------- 静态资源与结构 ---------- */

for (const f of ['docs/index.html', 'docs/app.js', 'docs/style.css']) {
  check(`asset exists: ${f}`, existsSync(join(ROOT, f)));
}
const html = readFileSync(join(ROOT, 'docs/index.html'), 'utf8');
const css = readFileSync(join(ROOT, 'docs/style.css'), 'utf8');
const app = readFileSync(join(ROOT, 'docs/app.js'), 'utf8');

check('index.html mentions gbz185 + GB/Z 185', html.includes('gbz185.mbt') && html.includes('GB/Z 185'));
check('index.html loads app.js / style.css', html.includes('app.js') && html.includes('style.css'));
check('html lang=zh-CN', html.includes('<html lang="zh-CN"'));
check('light theme default + dark palette', html.includes('data-theme="light"') && css.includes("html[data-theme='dark']"));
check('theme persistence key', html.includes('gbz185-mbt-theme') && app.includes('gbz185-mbt-theme'));
check('sticky topbar', css.includes('.topbar { position: sticky'));
check('nav has six anchors', ['#features', '#demo', '#start', '#api', '#quality', '#docs'].every((h) => html.includes(`href="${h}"`)));
check('theme toggle + github action', html.includes('id="theme-toggle"') && html.includes('github.com/walkzzz/gbz185.mbt'));
check('Open Graph metadata', html.includes('property="og:title"') && html.includes('property="og:description"') && html.includes('property="og:url"'));
check('inline svg favicon', html.includes('rel="icon"'));
check('skip link for a11y', html.includes('class="skip-link"'));
check('footer with project links', html.includes('class="footer"') && html.includes('mooncakes.io/docs/walkzzz/gbz185.mbt'));
check('no external script/style CDN', !/<script[^>]+src="https?:/.test(html) && !/<link[^>]+href="https?:/.test(html));
check('hero card live status', html.includes('id="hero-status"') && html.includes('id="hero-envelope"'));
check('12 capability cards', (html.match(/class="feature"/g) || []).length === 12, `${(html.match(/class="feature"/g) || []).length}`);
check('10 demo cards', (html.match(/<article class="card">/g) || []).length === 10, `${(html.match(/<article class="card">/g) || []).length}`);
check('copy targets >= 6', (html.match(/data-copy-target="/g) || []).length >= 6);
check('mobile nav toggle present', html.includes('id="nav-toggle"') && html.includes('aria-controls="site-nav"') && html.includes('id="site-nav"'));
check('mobile nav drawer css', css.includes('.nav.open { display: flex; }'));
check('mobile nav js bound', app.includes('nav-toggle') && app.includes('closeNav'));
check('int32 demo-range hint', html.includes('int32 演示范围'));

/* ---------- 既有钩子保持（不打断旧演示与 E2E） ---------- */

for (const id of ['sender', 'recipient', 'seq', 'timestamp', 'kind', 'payload', 'encode-out']) {
  check(`hook preserved: #${id}`, html.includes(`id="${id}"`));
}
for (const id of ['json', 'members', 'check-out', 'curseq', 'seq-out']) {
  check(`hook preserved: #${id}`, html.includes(`id="${id}"`));
}
for (const run of ['encode', 'validate', 'fanout', 'next']) {
  check(`data-run preserved: ${run}`, html.includes(`data-run="${run}"`));
}
check('presets preserved: event/heartbeat', html.includes('data-preset="event"') && html.includes('data-preset="heartbeat"'));

/* ---------- 新演示钩子 ---------- */

const newIds = [
  'meta-json', 'meta-out', 'flow-node', 'flow-peers', 'flow-kind', 'flow-payload', 'flow-out',
  'caps', 'required', 'caps-out', 'nodes', 'filter', 'discoverable', 'match-out',
  'aic', 'aic-out', 'group', 'route-members', 'route-recipient', 'route-out',
  'tool-name', 'tool-desc', 'tool-schema', 'tool-binding', 'tool-server', 'tool-out',
];
for (const id of newIds) {
  check(`new hook: #${id}`, html.includes(`id="${id}"`));
}
for (const run of ['meta', 'flow', 'caps', 'match', 'aic', 'route', 'tool', 'hero']) {
  check(`action bound: ${run}`, app.includes(`${run}:`) || app.includes(`data-run="${run}"`));
}

/* ---------- 文档链接与本地锚点 ---------- */

for (const doc of ['architecture', 'performance', 'comparison', 'assessment', 'proposal', 'migration', 'security', 'known-gaps', 'TEST_REPORT']) {
  check(`docs link: ${doc}.md`, html.includes(`docs/${doc}.md`));
}
for (const anchor of ['features', 'demo', 'start', 'api', 'quality', 'docs', 'how', 'top']) {
  check(`section anchor exists: #${anchor}`, html.includes(`id="${anchor}"`));
}

/* ---------- 版本与口径 ---------- */

const mod = readFileSync(join(ROOT, 'moon.mod'), 'utf8');
const version = (mod.match(/version\s*=\s*"([^"]+)"/) || [])[1] || '';
check('version matches moon.mod', version.length > 0 && html.includes(version), version);
check('badge numbers: tests 124 / 117 x 3', html.includes('124') && html.includes('117'));
check('badge numbers: mutation 19 / 19', html.includes('19 / 19'));
check('coverage number 91.8%', html.includes('91.8%'));
check('script assets present', existsSync(join(ROOT, 'scripts/mutation_test.mbtx')) && existsSync(join(ROOT, 'scripts/serve_pages.mjs')));

/* ---------- 构建 playground JS 并复制 ---------- */

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
if (!existsSync(JS_DOCS)) {
  console.log(`\n=== pages check: FAIL (${failures}/${total}) ===`);
  process.exit(1);
}

/* ---------- 导出与语义 ---------- */

const pg = await import(pathToFileURL(JS_DOCS).href);
const exportsList = [
  'aip_make_envelope',
  'aip_validate',
  'aip_fanout_count',
  'aip_next_seq',
  'aip_envelope_meta',
  'aip_protocol_flow',
  'capability_report',
  'discovery_match',
  'identity_aic_check',
  'route_resolve',
  'tool_descriptor_check',
];
for (const name of exportsList) {
  check(`export: ${name}`, typeof pg[name] === 'function');
}

const envelope = pg.aip_make_envelope(
  'urn:agent:a',
  'urn:agent:b',
  1,
  1700000000,
  'task_request',
  '{"text":"hi"}',
);
check('envelope has version 1 + protocol aip', envelope.includes('"envelope_version":"1"') && envelope.includes('"protocol":"aip"'));
check('envelope round-trips validation', pg.aip_validate(envelope) === true);
check('empty object rejected', pg.aip_validate('{}') === false);
check('unknown kind folds to error json', pg.aip_make_envelope('a', 'b', 1, 1, 'bogus', '{}').includes('"ok":false'));
check('invalid payload json folds to error', pg.aip_make_envelope('a', 'b', 1, 1, 'event', '{bad').includes('"ok":false'));
check('fanout expands 3 members', pg.aip_fanout_count(envelope, 'urn:agent:m1, urn:agent:m2, urn:agent:m3') === 3);
check('fanout on invalid json = -1', pg.aip_fanout_count('{}', 'a,b') === -1);
check('fanout with no members = -2', pg.aip_fanout_count(envelope, '  ') === -2);
check('empty sender rejected at encode', pg.aip_make_envelope('', 'urn:agent:b', 1, 1, 'event', '{}').includes('"ok":false'));
check('non-positive seq rejected at encode', pg.aip_make_envelope('a', 'b', 0, 1, 'event', '{}').includes('"ok":false'));
check('negative timestamp rejected', pg.aip_make_envelope('a', 'b', 1, -1, 'event', '{}').includes('"ok":false'));
check('validate rejects empty sender', pg.aip_validate(envelope.replace('"sender_urn":"urn:agent:a"', '"sender_urn":""')) === false);
check('validate rejects seq 0', pg.aip_validate(envelope.replace('"seq":1', '"seq":0')) === false);
check('next_seq(41) = 42', pg.aip_next_seq(41) === 42);

const meta = JSON.parse(pg.aip_envelope_meta(envelope));
check('envelope meta exposes sender/recipient', meta.sender_urn === 'urn:agent:a' && meta.recipient_urn === 'urn:agent:b');
check('envelope meta message_id is sender#seq', meta.message_id === 'urn:agent:a#1', meta.message_id);
check('envelope meta invalid json folds', JSON.parse(pg.aip_envelope_meta('{bad')).ok === false);

const flow = JSON.parse(
  pg.aip_protocol_flow('urn:agent:hero', 'urn:agent:p1, urn:agent:p2', 'task_request', '{"text":"x"}'),
);
check('protocol flow registers and sends', flow.is_registered === true && flow.outbox_seq === 1);
check('protocol flow delivers to peer', flow.delivered === true && flow.peer_watermark === 1);
check('protocol flow lists sorted peers', Array.isArray(flow.peers) && flow.peers.length === 2 && flow.peers[0] === 'urn:agent:p1');
check('protocol flow requires a peer', JSON.parse(pg.aip_protocol_flow('urn:agent:hero', '', 'event', '{}')).ok === false);

const capsCovered = JSON.parse(pg.capability_report('skill:demo, tool:file_read', 'skill:demo'));
check('capability covered + count', capsCovered.covered === true && capsCovered.count === 2 && capsCovered.missing.length === 0);
const capsMissing = JSON.parse(pg.capability_report('skill:demo', 'skill:demo, tool:net_fetch'));
check('capability missing diagnostic', capsMissing.covered === false && capsMissing.missing[0] === 'tool:net_fetch');

const nodesJson = JSON.stringify([
  {
    urn: 'urn:agent:a', display_name: 'A', discoverable: true,
    identity: { aic: '', identity_status: 'active', cai_ref: null, registered_at: null },
    acs: { capabilities: ['skill:demo'] },
  },
  {
    urn: 'urn:agent:b', display_name: 'B', discoverable: true,
    identity: { aic: '', identity_status: 'active', cai_ref: null, registered_at: null },
    acs: { capabilities: ['tool:file_read'] },
  },
  {
    urn: 'urn:agent:c', display_name: 'C', discoverable: false,
    identity: { aic: '', identity_status: 'active', cai_ref: null, registered_at: null },
    acs: { capabilities: ['skill:demo'] },
  },
]);
const hiddenFiltered = JSON.parse(pg.discovery_match(nodesJson, 'skill:demo', true));
check('discovery filters hidden nodes', hiddenFiltered.count === 1 && hiddenFiltered.urns[0] === 'urn:agent:a');
const hiddenIncluded = JSON.parse(pg.discovery_match(nodesJson, '', false));
check('discovery can include hidden nodes', hiddenIncluded.count === 3);
check('discovery invalid json folds', JSON.parse(pg.discovery_match('{bad', '', true)).ok === false);

const aicOk = JSON.parse(pg.identity_aic_check('1.2.156.185.2.1.42'));
check('AIC valid + stack prefix', aicOk.valid === true && aicOk.stack_prefix === true);
const aicBad = JSON.parse(pg.identity_aic_check('1'));
check('AIC single segment rejected', aicBad.valid === false && aicBad.stack_prefix === false);

const routeFanout = JSON.parse(pg.route_resolve('urn:agent:group:ops', 'urn:agent:m1, urn:agent:m2', 'urn:agent:group:ops'));
check('route resolves fanout members', routeFanout.decision === 'fanout' && routeFanout.members.length === 2);
const routeReject = JSON.parse(pg.route_resolve('urn:agent:group:ops', 'urn:agent:m1', 'urn:agent:unknown'));
check('route rejects unknown recipient', routeReject.decision === 'reject' && routeReject.ok === false);

const tool = JSON.parse(pg.tool_descriptor_check('net_fetch', 'fetch a URL', '{"type":"object"}', 'mcp', 'server-a'));
check('tool descriptor builds mcp entry', tool.mcp_entry.name === 'net_fetch' && tool.mcp_entry.inputSchema.type === 'object');
check('tool descriptor rejects empty name', JSON.parse(pg.tool_descriptor_check('', 'd', '{}', 'native', '')).ok === false);

/* ---------- 汇总 ---------- */

console.log(`\n=== pages check: ${failures === 0 ? 'PASS' : `FAIL (${failures})`} · ${total} checks ===`);
if (failures > 0) process.exit(1);
