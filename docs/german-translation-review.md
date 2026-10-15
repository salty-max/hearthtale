# German translation review: Hearthtale

15 October 2026. Reviewed baseline `afe9d2d`. Corrections applied locally.

## Verdict

The German interface is complete and mostly usable. The corrections clarify commands, manual Hardcore status, linking and completed actions. The welcome text now reads more naturally. The addon-list description also discloses that the actual diary is English, which is important for a German-speaking player deciding whether to install it.

**14 findings addressed** (8 P2, 6 P3). P2 marks meaning or functional clarity, P3 marks idiom or editorial clarity. This is an editorial review, not a claim of native signoff.

## Coverage

All 136 English/German interface pairs were read, including the book, entry editor, Hall of the Fallen, dates, counts, settings, welcome text, banners, slash-command help and chat feedback. Both German addon-list descriptions were reviewed and corrected. The website catalog contains only English. The writer, entry templates, diaries and saved narrative text remain outside this German-interface pass.

Every authored pair was read against its English key. Placeholder types and argument positions were checked across the complete catalog, including Second Wind's numbered German argument order. There are no missing German catalog entries or prose semicolons. All three addons retain `flagged: true` pending a native reader.

## Decisions and behavior

- The rewrite success message now uses `wurde neu geschrieben`. This is shown after confirmation and completion, not while asking permission to rewrite.
- Link-code feedback specifies six characters total. The real command and the `/reload` instruction remain unchanged and executable.
- Manual Hardcore markings explicitly say that the game does not report the status here. They must not look like a game-authenticated status.
- The Hall death summary restores `in` before the location. The incoming comma dropped the relationship between the cause of death and its place.
- Kept `Tagebuch`, `Grabinschrift`, `Halle der Gefallenen`, `Eintrag` and `du`. They fit the book and remain consistent across the interface.
- A German interface still saves the same English diary prose and the same stable recorded identity. A player's own German titles and notes survive both saving and a separately confirmed rewrite.

## Validation

- `bun run check`
- `bun run addon:package`
- 18 German runtime checks on Classic Era and 18 on Forever
- All 136 placeholder signatures and prose-semicolon checks
- German command, code, save and rewrite flows, including preservation of personal titles and notes

Generated locale files were rebuilt from their source catalogs. The shared-kit copy, saved data schema and English/French catalogs were not changed. No release, deployment or push is included.

## Limits

Keep the native-review flag. The English writer and English-only website are not missing German catalog entries and were not translated here. Some Hall labels, such as the race/class names captured when a character died, are saved snapshots and do not automatically change after switching the client language. Re-localizing those historical labels would be a separate display change. Real-client line wrapping remains unverified.

## Applied findings

The companion [JSON ledger](german-translation-review.json) contains the English keys, priorities, exact before/after values, resolution status and source hashes. Multi-file addon-list wording is one finding.

### HEARTHTALE-001 - P2

- Before: /ht öffnet das Tagebuch, /ht hall die Halle der Gefallenen. /ht title [N] TEXT benennt einen Eintrag, /ht note [N] TEXT schreibt an seinen Rand (ohne N der letzte Eintrag, ohne TEXT wird entfernt). /ht link CODE verknüpft diesen Charakter mit hearthtale.app. /ht settings öffnet die Optionen, /ht minimap blendet den Button ein oder aus, /ht welcome zeigt die Willkommensseite erneut. /ht export gibt die Einstellungen dieses Charakters als Code aus, /ht import CODE übernimmt sie. /ht rewrite schreibt das Tagebuch mit dieser Version neu (sonst behält ein abgeschlossener Eintrag seine Worte).
- After: /ht öffnet das Tagebuch, /ht hall die Halle der Gefallenen. /ht title [N] TEXT gibt einem Eintrag einen Titel, /ht note [N] TEXT fügt eine Randnotiz hinzu. Ohne N gilt der Befehl für den letzten Eintrag. Ohne TEXT wird der Titel bzw. die Notiz entfernt. /ht link CODE verknüpft diesen Charakter mit hearthtale.app. /ht settings öffnet die Optionen, /ht minimap blendet den Button ein oder aus, /ht welcome zeigt die Willkommensseite erneut. /ht export gibt die Einstellungen dieses Charakters als Code aus, /ht import CODE übernimmt sie. /ht rewrite schreibt das Tagebuch mit dieser Version neu. Abgeschlossene Einträge behalten sonst ihren bisherigen Text.

Explain precisely which entry is selected and what an omitted TEXT removes.

### HEARTHTALE-002 - P2

- Before: Sein Tod wird sein Buch schließen. Das Spiel kann es hier nicht angeben.
- After: Sein Tod schließt sein Buch. Das Spiel meldet hier keinen Hardcore-Status.

The missing game information is Hardcore status, not whether death will close a book.

### HEARTHTALE-003 - P2

- Before: So in den Optionen von Hearthtale markiert (das Spiel sagt es hier nicht).
- After: In den Optionen von Hearthtale als Hardcore markiert (hier nicht vom Spiel gemeldet).

Distinguish the manual marking from a status reported by the game.

### HEARTHTALE-004 - P3

- Before: Dieser Charakter ist Hardcore
- After: Dieser Charakter spielt im Hardcore-Modus

Use natural German for the setting label.

### HEARTHTALE-005 - P3

- Before: fiel durch %s
- After: getötet von %s

Name the killer directly in the Hall summary.

### HEARTHTALE-006 - P2

- Before: %s, %s
- After: %s in %s

Restore the location relationship. The incoming comma merely juxtaposed the cause of death and the place.

### HEARTHTALE-007 - P3

- Before: Jedes Mal, wenn du rastest, in einem Gasthaus, in einer Stadt oder an einem Lagerfeuer, wird der Weg seit der letzten Rast zu einem Eintrag, in der eigenen Stimme deines Charakters.
- After: Wenn du in einem Gasthaus, in einer Stadt oder an einem Lagerfeuer rastest, wird aus deinen Erlebnissen seit der letzten Rast ein Eintrag in der eigenen Stimme deines Charakters.

Remove an incorrect comma and the literal road becoming an entry.

### HEARTHTALE-008 - P2

- Before: Spiel wie immer: Hearthtale führt Buch. Die Quests, die zählten, die Gegner, die einen Namen verdienen, die Länder, die du zum ersten Mal siehst, die knappen Momente.
- After: Spiel wie immer: Hearthtale hält deine Erlebnisse fest. Die wichtigen Quests, die nennenswerten Gegner, die erstmals bereisten Länder und die Momente, in denen du dem Tod knapp entkommen bist.

Knappe Momente does not convey close calls with death.

### HEARTHTALE-009 - P2

- Before: das ist kein Verknüpfungscode: Er hat sechs Buchstaben und Ziffern, von hearthtale.app.
- After: das ist kein Verknüpfungscode. Er stammt von hearthtale.app und besteht aus sechs Zeichen (Buchstaben oder Ziffern).

The code has six characters total, not six letters plus digits.

### HEARTHTALE-010 - P2

- Before: das Tagebuch wird neu geschrieben. hearthtale.app zeigt es nach deinem nächsten Ausloggen oder /reload, während Ravenpost läuft.
- After: das Tagebuch wurde neu geschrieben. hearthtale.app zeigt es nach deinem nächsten Ausloggen oder /reload, während Ravenpost läuft.

This is the success message after the confirmed rewrite, not an action still in progress.

### HEARTHTALE-011 - P3

- Before: Code %s gespeichert. Logge dich aus oder mache /reload, während Ravenpost läuft, und dieses Buch kommt in deine Bibliothek auf hearthtale.app.
- After: Code %s gespeichert. Logge dich aus oder gib /reload ein, während Ravenpost läuft. Dann erscheint dieses Buch in deiner Bibliothek auf hearthtale.app.

Describe the command naturally and split the long instruction into readable sentences.

### HEARTHTALE-012 - P3

- Before: Der Tod dieses Charakters schließt sein Buch: eine Grabinschrift, und sein Tagebuch kommt in die Halle der Gefallenen. Nur für diesen Charakter.
- After: Nur für diesen Charakter: Sein Tod schließt das Tagebuch mit einer Grabinschrift. Das Buch wird in der Halle der Gefallenen aufbewahrt.

Replace a literal fragment with a complete explanation of the setting's effect and scope.

### HEARTHTALE-013 - P3

- Before: Kopiere ihn (Strg+C), dann bei einem anderen Charakter: Code verwenden, oder /ht import CODE.
- After: Kopiere ihn (Strg+C). Wähle dann bei einem anderen Charakter 'Code verwenden' oder nutze /ht import CODE.

Identify the actual button and preserve the executable command.

### HEARTHTALE-014 - P2

- Before: Das Tagebuch deines Charakters, geschrieben, während du spielst, mit einer Grabinschrift und einem aufbewahrten Tagebuch, wenn ein Hardcore-Leben endet.
- After: Führt beim Spielen das Tagebuch deines Charakters auf Englisch. Endet ein Hardcore-Leben, bleibt sein Buch mit einer Grabinschrift erhalten.

State explicitly that the diary is English. A localized addon-list description otherwise leaves German readers expecting translated journal entries.
