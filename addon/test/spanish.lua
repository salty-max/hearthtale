-- Same interface-only scope as german.lua, with both Spanish clients and
-- both games. Diary prose, stored names, titles and notes keep their words.
LOCALE = os.getenv("LOCALE") or "esES"
assert(LOCALE == "esES" or LOCALE == "esMX", "choose a Spanish locale")
local G = dofile("addon/test/game.lua")
local ns, L = G.ns, G.ns.kit.L
local passed = 0
local function check(cond, msg, got)
  assert(cond, msg .. (not cond and got and (": got " .. tostring(got)) or ""))
  passed = passed + 1
  io.stdout:write("✓ ", msg, "\n")
end
local function last() return G.printed[#G.printed] or "" end
local function contains(text, part) return text and text:find(part, 1, true) ~= nil end
local function rendered(part)
  for _, text in ipairs(G.rendered) do
    if contains(text, part) then return true end
  end
  return false
end
local function slash(text) SlashCmdList.HEARTHTALE(text) end

-- Client API fixtures from wow-data. Display labels use the life being
-- read, not the current player's sex. The writer keeps its English tokens.
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Guerrero", PALADIN = "Paladín" }
LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "Guerrera", PALADIN = "Paladín" }
local areas = { [1] = "Dun Morogh", [77] = "Yunquemar", [132] = "Valle de Crestanevada" }
C_Map = { GetAreaInfo = function(id) return areas[id] end }
G.state.sub, G.state.bind = "Valle de Crestanevada", "Yunquemar"
check(ns.locale == LOCALE and GetLocale() == LOCALE and L["Journal"] == "Diario", "the Spanish client's own catalog")
check(L["A word Hearthtale never says"] == "A word Hearthtale never says", "unknown keys retain the English fallback")
check(
  ns.upper("prólogo, última entrada y año") == "PRÓLOGO, ÚLTIMA ENTRADA Y AÑO",
  "Spanish accented capitals and ñ"
)
for _, n in ipairs({ 0, 1, 2 }) do
  check(
    ns.kit.plural(n, "%d entry", "%d entries"):format(n) == ("%d %s"):format(n, n == 1 and "entrada" or "entradas"),
    n .. " entries: Spanish plural rule"
  )
end
G.login()
check(contains(last(), "Empiezas la entrada 1. Escribe /ht"), "the first login message", last())
check(
  rendered("El diario de tu personaje, escrito en inglés mientras juegas."),
  "the welcome states that diary prose is English"
)
check(
  rendered("Opciones de Sealinedion") and rendered("Compartir lo que ves"),
  "the shared welcome interface is translated"
)
check(G.panel.settings.HEARTHTALE_TOAST.name == "Aviso al cerrarse un libro", "the settings label")
if G.forever then
  check(
    G.panel.settings.HEARTHTALE_HARDCORE.name == "Este personaje es Hardcore",
    "Forever's explicit Hardcore setting"
  )
  ns.setHardcore(true)
else
  check(G.panel.settings.HEARTHTALE_HARDCORE == nil, "Classic uses the game's Hardcore status")
end
local journal = ns.journal()
check(journal.race == "Dwarf" and journal.class == "PALADIN", "the writer's recorded identity stays in English tokens")
check(
  journal.chapters[1].start.sub == "Coldridge Valley",
  "a Spanish client place is stored in the writer's English",
  journal.chapters[1].start.sub
)

slash("what")
check(contains(last(), "/ht abre el diario y /ht hall abre el Salón de los Caídos."), "Spanish command help")
check(
  contains(last(), "/ht title [N] TEXT") and contains(last(), "/ht note [N] TEXT") and contains(last(), "/ht rewrite"),
  "help preserves executable command names and arguments"
)
slash("link BAD")
check(contains(last(), "seis caracteres (letras o dígitos)"), "an invalid link code explains its total length")
slash("link ab12cd")
check(journal.link.code == "AB12CD", "the actual site link code is preserved")
check(
  contains(last(), "Cierra sesión o usa /reload con Ravenpost abierto"),
  "link feedback gives an executable upload instruction"
)
slash("import BAD")
check(contains(last(), "Ese código de opciones no es de Hearthtale."), "an invalid settings code")
local code = ns.exportCode()
check(code:find("^HT1:") and ns.importCode(code), "Spanish UI preserves the settings-code protocol")
slash("import " .. code)
check(contains(last(), "Se han importado las opciones de este personaje."), "settings import feedback")
ns.setOption("toast", true)
ns.setOption("minimapHidden", true)
ns.onResume(1, false)
check(
  last() == ns.PREFIX .. "Retomas la entrada 1. Escribe /ht para leer el diario.",
  "resume feedback when the minimap button is hidden"
)
ns.setOption("minimapHidden", false)
ns.onResume(1, false)
check(contains(last(), "haz clic en el botón junto al minimapa"), "resume feedback when the button is visible")

-- The player's text survives saving and a separately confirmed rewrite.
slash("title 1 Mi primer día")
check(contains(last(), "Se ha guardado el título de la entrada 1."), "title-save feedback")
slash("note 1 Un frío de narices. Mañana vuelvo.")
check(contains(last(), "Se ha guardado la nota de la entrada 1."), "note-save feedback")
local before = ns.writeBook(journal).chapters[1]
check(
  before.title == "Mi primer día" and before.note == "Un frío de narices. Mañana vuelvo.",
  "player titles and notes keep Spanish accents"
)
ns.openChapter(1)
check(
  HearthtalePage.title:GetText() == "Mi primer día"
    and HearthtalePage.asides[1]:IsShown()
    and HearthtalePage.asides[1].text:GetText() == before.note,
  "the page renders the player title, and the note in its margin"
)
check(
  contains(HearthtalePage.sub:GetText(), "Entrada 1") and contains(HearthtalePage.sub:GetText(), "en curso"),
  "the entry's header line"
)
check(contains(HearthtalePage.note:GetText(), before.text), "the rendered diary prose keeps its original words")
G.logout()
local saved = journal.book
check(saved.chapters[1].diary == before.text, "Spanish UI saves the original diary prose")
slash("rewrite")
check(G.popups[#G.popups] == "HEARTHTALE_REWRITE" and journal.book == saved, "a rewrite request waits for confirmation")
check(
  contains(StaticPopupDialogs.HEARTHTALE_REWRITE.text, "Tus títulos y notas se conservarán."),
  "the rewrite dialog explains what is preserved"
)
StaticPopupDialogs.HEARTHTALE_REWRITE.OnAccept()
local after = ns.writeBook(journal).chapters[1]
check(contains(last(), "Se ha vuelto a escribir el diario."), "confirmed rewrite feedback")
check(
  after.title == before.title and after.note == before.note,
  "a confirmed rewrite preserves the player's title and note"
)
check(after.text == before.text, "rewriting with the same writer leaves English prose unchanged")
slash("note 1")
check(contains(last(), "Se ha eliminado la nota de la entrada 1.") and ns.own(1).text == nil, "note removal feedback")
slash("title 1")
check(contains(last(), "Se ha eliminado el título de la entrada 1.") and ns.own(1) == nil, "title removal feedback")
slash("title 1 Mi primer día")
slash("note 1 Un frío de narices. Mañana vuelvo.")

-- Race names remain regional even though esMX borrows interface prose.
local race, class = ns.lifeNames({
  race = "Dwarf",
  class = "WARRIOR",
  sex = 3,
  raceName = "Dwarf",
  className = "Warrior",
  locale = "enUS",
})
check(race == "Enana" and class == "Guerrera", "a historical woman's race and class are localized by token and sex")
race, class = ns.lifeNames({ race = "Dwarf", class = "WARRIOR", sex = 2 })
check(race == "Enano" and class == "Guerrero", "a historical man's labels don't take the female reader's gender")
race = ns.lifeNames({ race = "Skyborne", sex = 3 })
check(
  race == (LOCALE == "esMX" and "Cielonata de la Suma Orden" or "Cielonata de la Orden Eminente"),
  "the Hall retains each Spanish client's own race names"
)
check(
  L["fallen"] == "sin vida" and ns.FALLEN_SEAL[2] == "Sin vida",
  "individual death labels work for every historical character"
)

-- Read the actual header formatting for same-day and cross-month/year dates.
local chapter = journal.chapters[1]
local originalStart, originalEnd, originalBook = ns.copy(chapter.start), chapter.ended, journal.book
local function at(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end
for _, range in ipairs({
  { at(2026, 10, 5), at(2026, 10, 5), "5 oct 2026" },
  { at(2026, 10, 5), at(2026, 10, 7), "5 a 7 oct 2026" },
  { at(2026, 9, 30), at(2026, 10, 2), "30 sep a 2 oct 2026" },
  { at(2026, 12, 30), at(2027, 1, 2), "30 dic 2026 a 2 ene 2027" },
}) do
  chapter.start.at = range[1]
  chapter.ended = {
    at = range[2],
    level = 1,
    zone = "Dun Morogh",
    sub = "Coldridge Valley",
    place = "Coldridge Valley",
    how = "rest",
  }
  journal.book = nil
  ns.forgetWritten(journal)
  ns.openChapter(1)
  check(
    contains(HearthtalePage.sub:GetText(), range[3]),
    "an assembled date range: " .. range[3],
    HearthtalePage.sub:GetText()
  )
end
chapter.start, chapter.ended, journal.book = originalStart, originalEnd, originalBook
ns.forgetWritten(journal)

-- The Hall's cards use whole, gender-neutral descriptions of death.
ns.openHall()
check(HearthtalePage.title:GetText() == "El Salón de los Caídos", "the Hall's translated title")
check(rendered("Aún no ha caído nadie. Que siga así."), "the empty Hall's message")
local deaths = {
  { cause = "foe", foe = "Timber", text = "murió a manos de Timber" },
  { cause = "drowning", text = "se ahogó" },
  { cause = "lava", text = "murió por quemaduras" },
  { cause = "fall", text = "cayó" },
  { cause = "nature", text = "cayó" },
}
for i, d in ipairs(deaths) do
  local life = ns.copy(journal)
  life.guid, life.name, life.class, life.sex, life.closed = "Player-Spanish-" .. i, "Vida " .. i, "WARRIOR", 3, true
  life.death = { cause = d.cause, foe = d.foe, zone = "Dun Morogh", level = 8, at = G.clock() + i }
  life.raceName, life.className, life.locale = "Dwarf", "Warrior", "enUS"
  HearthtaleHall.lives[life.guid] = life
end
ns.openHall("overview")
for _, card in ipairs(HearthtalePage.cards) do
  local n = tonumber((card.name:GetText() or ""):match("^Vida (%d+)$"))
  if n then
    check(
      contains(card.facts:GetText(), "Nivel 8, Enana Guerrera, " .. deaths[n].text .. " en Dun Morogh"),
      "the Hall card for " .. deaths[n].cause,
      card.facts:GetText()
    )
  end
end
check(rendered("Aquí se recuerdan 5 vidas"), "the Hall's plural count")

-- A real Hardcore death: banner, link, closed-book header and saved history.
G.state.health = 0
G.fire("PLAYER_DEAD")
check(journal.closed and ns.fallenLife(journal.guid), "a real Hardcore death closes the book and keeps it in the Hall")
check(
  contains(last(), "El diario de Sealinedion se ha cerrado. Se conserva en el ")
    and contains(last(), "|h[Salón de los Caídos]|h"),
  "the complete Hall chat sentence and clickable link",
  last()
)
local banner = G.toasted[#G.toasted]
check(
  banner
    and banner.kicker == "El libro se ha cerrado"
    and banner.tip == "Haz clic para leerlo en el Salón de los Caídos",
  "the translated death banner"
)
ns.openHall(journal.guid)
check(
  HearthtalePage.sub:GetText():find("^Hardcore  \194\183  sin vida  \194\183  "),
  "the Hall epitaph's gender-neutral header"
)
check(
  contains(HearthtalePage.sub:GetText(), "Enana Paladín"),
  "the epitaph uses localized race and client class labels"
)
G.logout()
check(
  G.saved().notes[1].title == "Mi primer día" and G.saved().notes[1].text == "Un frío de narices. Mañana vuelvo.",
  "saved titles and notes survive the death and logout"
)
check(
  G.saved().book.chapters[1].diary and #G.saved().book.chapters[1].diary > 0,
  "the closed journal still saves its diary prose"
)

local output = os.getenv("SPANISH_REPORT")
if output then
  local file = assert(io.open(output, "w"))
  file:write(
    "Locale: ",
    LOCALE,
    "\n\n",
    L["Your character's own journal, written as you play."],
    "\n\n",
    HearthtalePage.sub:GetText(),
    "\n\n",
    last(),
    "\n\n"
  )
  for _, card in ipairs(HearthtalePage.cards) do
    if card.name and card.name:GetText() ~= "" then
      file:write(card.name:GetText(), "\n", card.facts:GetText(), "\n")
    end
  end
  file:write("\nOriginal diary prose:\n", before.text or "", "\n")
  file:close()
end
io.stdout:write(("%s, %s: %d checks passed\n"):format(G.forever and "Forever" or "Classic Era", LOCALE, passed))
