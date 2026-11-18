export function parseRepo(value) {
  let url;
  try { url = new URL(value); } catch { throw Error('Provide a valid GitHub repository URL'); }
  if (url.protocol !== 'https:' || url.hostname !== 'github.com' || url.username || url.password || url.port || url.search || url.hash) throw Error('Only GitHub repository root URLs are supported');
  const parts = url.pathname.replace(/\/$/, '').split('/').filter(Boolean);
  if (parts.length !== 2 || !parts.every(p => /^[a-zA-Z0-9_.-]+$/.test(p)) || parts.some(p => p === '.' || p === '..')) throw Error('Use a repository root URL');
  return parts.join('/');
}

export function validMilestonePath(file) {
  return typeof file === 'string' && file.length <= 256 && /^(?!\/)(?!.*\.\.)(?!.*\\)[\w./-]+\.md$/i.test(file);
}

export function parseWebsiteUrl(value) {
  if (typeof value !== 'string' || value.length > 2048) throw Error('Invalid HTTPS website URL');
  let url;
  try { url = new URL(value); } catch { throw Error('Invalid HTTPS website URL'); }
  if (url.protocol !== 'https:' || !url.hostname || url.username || url.password || (url.port && url.port !== '443')) throw Error('Invalid HTTPS website URL');
  return url.toString();
}

export function milestoneParse(md) {
  let section = 'General';
  const tasks = [];
  for (const line of md.split(/\r?\n/)) {
    const heading = line.match(/^#{1,6}\s+(.+)/);
    if (heading) { section = heading[1].trim(); continue; }
    const item = line.match(/^\s*[-*]\s+\[([ xX])\]\s+(.+)/);
    if (item) tasks.push({ section, done: item[1].toLowerCase() === 'x', text: item[2].trim() });
  }
  return tasks;
}
