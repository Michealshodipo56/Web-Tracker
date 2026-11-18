import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseRepo, parseStoredRepo, validMilestonePath, parseWebsiteUrl, milestoneParse } from './core.js';

test('repository parser accepts only GitHub roots', () => {
  assert.equal(parseRepo('https://github.com/Michealshodipo56/Web-Tracker'), 'Michealshodipo56/Web-Tracker');
  for (const url of ['https://github.com/a/b/tree/main', 'https://github.com/a/b?x=1', 'https://github.com@evil.example/a/b', 'http://github.com/a/b', 'https://github.com/a/..']) {
    assert.throws(() => parseRepo(url), url);
  }
});

test('stored repository slugs resolve for milestone sync', () => {
  assert.equal(parseStoredRepo('Michealshodipo56/Web-Tracker'), 'Michealshodipo56/Web-Tracker');
  for (const value of ['https://github.com/a/b', 'a/b/tree/main', '../b', 'a/b?ref=main']) {
    assert.throws(() => parseStoredRepo(value), value);
  }
});

test('milestone path forbids traversal and accepts nested Markdown', () => {
  assert.equal(validMilestonePath('docs/MILESTONES.md'), true);
  for (const path of ['../secrets.md', '/etc/passwd.md', 'a\\b.md', 'a.txt', '']) assert.equal(validMilestonePath(path), false);
});

test('website URL requires HTTPS without embedded credentials', () => {
  assert.equal(parseWebsiteUrl('https://example.org/'), 'https://example.org/');
  for (const url of ['javascript:alert(1)', 'http://example.org', 'https://user:pass@example.org', 'https://example.org:8443']) assert.throws(() => parseWebsiteUrl(url), url);
});

test('checkbox parser retains sections and task state', () => {
  assert.deepEqual(milestoneParse('# Build\n- [x] API\n- [ ] UI\n## Launch\n* [X] TLS'), [
    { section: 'Build', done: true, text: 'API' },
    { section: 'Build', done: false, text: 'UI' },
    { section: 'Launch', done: true, text: 'TLS' },
  ]);
});
