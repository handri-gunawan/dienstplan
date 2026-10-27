// Uebernimmt Homescreen-Angaben (Titel, Symbol, Farben) aus der Klartext-Fassung
// in die verschluesselte Seite und ergaenzt "noindex".
// Aufruf: node tools/inject-head.js <Quelle.html> <index.html>
const fs = require("fs");
const [src, out] = process.argv.slice(2);
if (!src || !out) { console.error("Aufruf: node inject-head.js <Quelle.html> <index.html>"); process.exit(1); }

const s = fs.readFileSync(src, "utf8");
let o = fs.readFileSync(out, "utf8");

const tags = [];
const metaRe = /<meta\s+name="(apple-mobile-web-app-[^"]*|mobile-web-app-capable|theme-color)"[^>]*>/gi;
for (const m of s.matchAll(metaRe)) tags.push(m[0]);
const icon = s.match(/<link\s+rel="apple-touch-icon"[^>]*>/i);
if (icon) tags.push(icon[0]);
tags.push('<meta name="robots" content="noindex, nofollow">');

// alte Einfuegung entfernen, falls das Skript zweimal laeuft
o = o.replace(/<!-- homescreen:start -->[\s\S]*?<!-- homescreen:end -->\s*/g, "");
const block = "<!-- homescreen:start -->\n" + tags.join("\n") + "\n<!-- homescreen:end -->\n";
if (!/<\/head>/i.test(o)) { console.error("Kein </head> in " + out); process.exit(1); }
o = o.replace(/<\/head>/i, block + "</head>");
fs.writeFileSync(out, o, "utf8");
console.log("Eingefuegt: " + tags.length + " Tags (Symbol: " + (icon ? "ja" : "nein") + ")");
