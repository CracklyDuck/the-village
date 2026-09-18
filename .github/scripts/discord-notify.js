// Posts a modpack update notice to a Discord webhook.
// Driven entirely by env vars so the workflow can pass inputs without
// interpolating them into a shell command.
//
// Run locally without sending anything:
//   DRY_RUN=true MESSAGE="test" VARIANT=latest REQUIRED=true node .github/scripts/discord-notify.js

const fs = require('fs');

const {
  WEBHOOK = '',
  MESSAGE = '',
  VARIANT = 'latest',
  REQUIRED = 'true',
  MENTION = 'false',
  DRY_RUN = 'false',
} = process.env;

const dryRun = DRY_RUN === 'true';
const required = REQUIRED === 'true';
const mention = MENTION === 'true';

if (!MESSAGE.trim()) {
  console.error('MESSAGE is empty - nothing to announce.');
  process.exit(1);
}
if (!dryRun && !WEBHOOK) {
  console.error('DISCORD_WEBHOOK secret is not set on this repository.');
  process.exit(1);
}

const variants = VARIANT === 'both' ? ['latest', 'full'] : [VARIANT];

function mcVersion(variant) {
  const file = `${variant}/pack.toml`;
  if (!fs.existsSync(file)) throw new Error(`${file} not found - is "${variant}" a real pack folder?`);
  const m = fs.readFileSync(file, 'utf8').match(/^minecraft\s*=\s*"(.*)"/m);
  if (!m) throw new Error(`no minecraft version in ${file}`);
  return m[1];
}

const packs = variants.map(v => `\`${v}\` — Minecraft ${mcVersion(v)}`).join('\n');

// Discord limits: title 256, description 4096, field value 1024.
const clip = (s, n) => (s.length > n ? s.slice(0, n - 1) + '…' : s);

const payload = {
  content: mention ? '@everyone' : '',
  allowed_mentions: { parse: mention ? ['everyone'] : [] },
  embeds: [
    {
      title: required ? 'Update required — The Village' : 'The Village updated',
      description: clip(MESSAGE.trim(), 4096),
      color: required ? 0xe74c3c : 0x2ecc71,
      fields: [{ name: 'Pack', value: clip(packs, 1024) }],
      footer: {
        text: required
          ? 'You need this update to join the server. Re-run the installer to sync.'
          : 'Re-run the installer when convenient.',
      },
    },
  ],
};

if (dryRun) {
  console.log(JSON.stringify(payload, null, 2));
  process.exit(0);
}

(async () => {
  const res = await fetch(WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const body = await res.text();
  if (!res.ok) {
    console.error(`Discord rejected the message: ${res.status} ${body}`);
    process.exit(1);
  }
  console.log(`Sent. Discord responded ${res.status}.`);
})();
