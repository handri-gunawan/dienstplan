// Ergaenzt die Klartext-Fassung vor dem Verschluesseln um App-Verhalten,
// das nicht im Generator (Skill) steckt:
//  - beim Oeffnen direkt zum aktuellen Wochenende springen
//  - kommt die App an einem spaeteren Tag aus dem Hintergrund zurueck, neu laden
//  - optional eigenes Homescreen-Symbol aus tools/apple-touch-icon.png
// Aufruf: node tools/inject-app.js <Quelle.html> <Ziel.html>
const fs = require("fs");
const path = require("path");
const [src, out] = process.argv.slice(2);
if (!src || !out) { console.error("Aufruf: node inject-app.js <Quelle.html> <Ziel.html>"); process.exit(1); }

let h = fs.readFileSync(src, "utf8");

const skript = `<!-- app:start -->
<script>
/* Eingefuegt von dienstplan-pages/tools/inject-app.js */
(function () {
  function springe() {
    if (location.hash) return;
    var k = document.querySelector(".week.next");
    if (k) k.scrollIntoView({ block: "start", behavior: "auto" });
  }
  setTimeout(springe, 60);
  window.addEventListener("pageshow", function (e) { if (e.persisted) springe(); });
  var tag = new Date().toDateString();
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "visible" && new Date().toDateString() !== tag) {
      location.reload();
    }
  });
})();
</script>
<!-- app:end -->
`;
h = h.replace(/<!-- app:start -->[\s\S]*?<!-- app:end -->\s*/g, "");
const ende = h.lastIndexOf("</body>");
if (ende < 0) { console.error("Kein </body> in " + src); process.exit(1); }
h = h.slice(0, ende) + skript + h.slice(ende);

let symbol = "Standard";
const png = path.join(__dirname, "apple-touch-icon.png");
if (fs.existsSync(png)) {
  const b64 = fs.readFileSync(png).toString("base64");
  const neu = '<link rel="apple-touch-icon" href="data:image/png;base64,' + b64 + '">';
  if (/<link\s+rel="apple-touch-icon"[^>]*>/i.test(h)) {
    h = h.replace(/<link\s+rel="apple-touch-icon"[^>]*>/i, () => neu);
  } else {
    h = h.replace(/<\/head>/i, () => neu + "\n</head>");
  }
  symbol = "tools/apple-touch-icon.png";
}

fs.writeFileSync(out, h, "utf8");
console.log("App-Ergaenzung eingefuegt (Symbol: " + symbol + ")");
