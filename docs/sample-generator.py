#!/usr/bin/env python3
"""Chronicle sample 2: the character's own journal, in the first person, one
chapter per level. Each chapter gathers what the level held: where I went,
what I did, whom I fought and met, what I learned, what nearly killed me.
Templates chosen by context, filled from the events, stable per event; a
sentence never used twice; a place just named becomes "there"."""
import hashlib, re

NAME, RACE, CLASS = "Sealinedion", "dwarf", "paladin"
HC = True

def seed(*parts):
  return int(hashlib.sha1("|".join(map(str, parts)).encode()).hexdigest(), 16)

used = set()
def pick(options, *key):
  fresh = [o for o in options if o not in used] or options
  o = fresh[seed(*key) % len(fresh)]
  used.add(o)
  return o

def words(n):
  w = ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"]
  return w[n] if n < len(w) else str(n)

def listing(items):
  items = list(items)
  if len(items) == 1: return items[0]
  return ", ".join(items[:-1]) + " and " + items[-1]

def cap(s):
  return re.sub(r"(^|[.!?] )([a-z])", lambda m: m.group(1) + m.group(2).upper(), s)

# ── the sentences, per kind of moment ────────────────────────────────────────
OPEN = {  # how a chapter opens: where the level began, and the hour
  "day": ["Morning at {where}.", "I woke at {where} to a clear sky.", "The day found me at {where}.", "I set out from {where}."],
  "night": ["Night at {where}, and a long one.", "I started this one at {where}, after dark.", "{where}, by lamplight."],
  "snow": ["Snow again at {where}.", "{where}, and the snow had not stopped."],
}
NEWPLACE = {
  1: ["I found {p}.", "I came upon {p}.", "The road showed me {p}."],
  2: ["I walked {p} for the first time.", "New ground: {p}.", "I saw {p}, which I had only heard of."],
}
TOWN = ["{t} at last: a roof, a forge and other people.", "I reached {t}. The inn's windows were the best thing I had seen in days.", "{t}. I stood in the square a while just to be among people."]
QUESTS = {
  "few": ["I did what {giver} asked of me: {q}.", "{giver} had work for me: {q}. Done.", "I saw to {q}, for {giver}."],
  "many": ["A busy stretch: {n} errands for the people here, {q} among them.", "{n} tasks done, {q} the one I'll remember.", "I worked: {n} jobs in all, the best of them {q}."],
}
KILLS = {
  "one": ["I put down {n} {foes} {at}.", "{n} {foes} fell to my hammer {at}.", "I thinned the {foes} {at}: {n} of them."],
  "two": ["{n1} {foes1} and {n2} {foes2} {at}; the hammer was busy.", "I fought {foes1} and {foes2} {at}: {n1} and {n2}, if anyone is counting. I am."],
}
FIRSTKIND = ["I met my first {foes} {at}.", "I'd never fought {foes} before {at}; now I have.", "{foes}, for the first time, {at}. They are worse up close."]
RARE = ["{foe} fell to me {at}. I kept a trophy, and I keep thinking about it.", "I brought down {foe} {at}. The hunters will want to hear it.", "{foe}. I won't pretend it was easy; I'll only say it was me who walked away."]
CLOSE = {
  "deep": ["It came down to a breath {at}. {foe_cap} had me at {hp}%, and on this realm there are no second chances. I didn't need one, this time.",
           "{foe_cap} nearly ended me {at}: {hp}% of my life left, and my hands shaking after. I sat down in the snow and stayed there a long time."],
  "light": ["{foe_cap} took me down to {hp}% {at}. Too close.", "I let {foe} get the better of me {at}, down to {hp}%. Careless. I won't be again."],
}
TRAIN = ["At the trainer I learned {s}.", "The trainer in {city} taught me {s}.", "New prayers from the trainer: {s}."]
LOOT = ["The best thing I took: {item}.", "I came away with {item}, and I'll wear it gladly.", "{item_cap}, and I didn't even have to pay for it."]
INN = ["I took a room at {place}.", "Home is {place} now.", "I set my hearthstone at {place}; the innkeeper knows my name."]
FLIGHT = ["I flew for the first time, from {a} to {b}. A dwarf is not built for the sky, and I told the gryphon so.", "Gryphon from {a} to {b}. My stomach stayed in {a}."]
GROUP = ["I went with {mates} into {place}, and we all came out again, which is the important part. {boss} didn't.", "{place}, with {mates}: five went in, five came out, and {boss} stayed. Not every party on this realm can say as much."]
CLOSE_CH = {  # how a chapter closes: time spent, gold, the level
  "short": ["It went quickly: {time}.", "{time} for this one.", "Not long: {time}."],
  "long": ["{time} at it, all told, and {gold} richer.", "A long level: {time}. I came out of it {gold} richer and a little wiser.", "{time}, {gold} in my purse, and I'm still here."],
}

# ── the life (imaginary; every place, creature and quest is the original game's) ─
L = [
 dict(level=1, where="Anvilmar", hour="day", places=["Coldridge Valley"], quests=(["Dwarven Outfitters", "A New Threat"], "Sten Stoutarm"), kills=[("Ragged Young Wolf", "wolves", 6), ("Rockjaw Trogg", "troggs", 9)], first="troggs", at="Coldridge Valley", time="22 minutes", gold="a few coppers"),
 dict(level=2, where="Anvilmar", hour="snow", quests=(["Coldridge Valley Mail Delivery"], "Balir Frosthammer"), kills=[("Burly Rockjaw Trogg", "troggs", 12)], at="the valley's edge", train="Blessing of Might", time="25 minutes", gold="a silver"),
 dict(level=3, where="Coldridge Valley", hour="day", quests=(["The Troll Cave", "The Stolen Journal"], "Felix Whindlebolt"), kills=[("Frostmane Troll Whelp", "Frostmane trolls", 14)], first="Frostmane trolls", at="the troll cave", close=("a Frostmane Novice", 9), time="38 minutes", gold="two silver"),
 dict(level=4, where="Coldridge Valley", hour="night", places=["Coldridge Pass"], quests=(["Senir's Observations"], "Mountaineer Thalos"), kills=[("Frostmane Novice", "Frostmane trolls", 8)], at="Coldridge Pass", train="Judgement", time="41 minutes", gold="three silver"),
 dict(level=5, where="Coldridge Pass", hour="snow", town="Kharanos", inn="the Thunderbrew Distillery", quests=(["Scalding Mornbrew Delivery", "Beer Basted Boar Ribs", "The Boar Hunter"], "the folk of Kharanos"), kills=[("Small Crag Boar", "boars", 10), ("Ragged Timber Wolf", "wolves", 7)], at="the fields around Kharanos", time="52 minutes", gold="five silver"),
 dict(level=6, where="Kharanos", hour="day", places=["Brewnall Village", "Gnomeregan's outer gates"], quests=(["Bitter Rivals", "Tools for Steelgrill"], "Rejold Barleybrew"), kills=[("Leper Gnome", "leper gnomes", 11)], first="leper gnomes", at="Brewnall Village", train="Divine Protection", time="an hour and five minutes", gold="seven silver"),
 dict(level=7, where="Kharanos", hour="night", places=["Shimmer Ridge"], quests=(["Frostmane Hold"], "Senir Whitebeard"), kills=[("Frostmane Snowstrider", "Frostmane trolls", 13)], at="Shimmer Ridge", loot="a pair of mail gauntlets, my first", time="an hour and ten minutes", gold="nine silver"),
 dict(level=8, where="Shimmer Ridge", hour="day", places=["Frostmane Hold"], quests=(["The Grizzled Den", "Stocking Jetsteam"], "Pilot Stonegear"), kills=[("Wendigo", "wendigos", 9), ("Frostmane Seer", "Frostmane trolls", 6)], first="wendigos", at="the Grizzled Den", train="Hammer of Justice", time="an hour and twenty minutes", gold="eleven silver"),
 dict(level=9, where="Kharanos", hour="night", rare="Timber", at="Shimmer Ridge", quests=(["The Perfect Stout", "Protecting the Herd"], "Rejold Barleybrew"), kills=[("Winter Wolf", "wolves", 15)], time="an hour and twenty-five minutes", gold="fourteen silver"),
 dict(level=10, where="Gol'Bolar Quarry", hour="day", quests=(["Ammo for Rumbleshot"], "Loslor Rudge"), kills=[("Rockjaw Bonesnapper", "troggs", 12)], at="Gol'Bolar Quarry", train="Lay on Hands", city="Ironforge", time="an hour and a half", gold="a gold piece"),
 dict(level=11, where="Kharanos", hour="night", close=("a Frostmane Shadowcaster", 12), at="Frostmane Hold", quests=(["Bitter Rivals"], "Rejold Barleybrew"), kills=[("Frostmane Shadowcaster", "Frostmane trolls", 10)], time="an hour and forty minutes", gold="a gold piece and a half"),
 dict(level=12, where="the North Gate", hour="day", places=["Loch Modan", "the Valley of Kings"], town="Thelsamar", inn="the inn at Thelsamar", quests=(["Rat Catching", "Thelsamar Blood Sausages"], "the folk of Thelsamar"), kills=[("Mountain Boar", "boars", 9), ("Tunnel Rat Kobold", "kobolds", 14)], first="kobolds", at="the hills above Thelsamar", time="an hour and three-quarters", gold="two gold"),
]

def chapter(e):
  out = []
  hour = e["hour"]
  out.append(pick(OPEN[hour], "open", e["level"]).format(where=e["where"]))
  last = [e["where"]]
  def at(place):
    if place == last[0]: return "there"
    last[0] = place
    return "at " + place if not place.startswith("the ") else "in " + place
  for i, p in enumerate(e.get("places", [])):
    out.append(pick(NEWPLACE[1 if i == 0 else 2], "place", p).format(p=p))
    last[0] = p
  if e.get("town"):
    out.append(pick(TOWN, "town", e["town"]).format(t=e["town"]))
    last[0] = e["town"]
  if e.get("inn"):
    out.append(pick(INN, "inn", e["inn"]).format(place=e["inn"]))
  qs, giver = e["quests"]
  q = listing([f"“{x}”" for x in qs])
  if len(qs) <= 2:
    out.append(pick(QUESTS["few"], "q", e["level"]).format(q=q, giver=giver))
  else:
    out.append(pick(QUESTS["many"], "q", e["level"]).format(n=words(len(qs)), q=f"“{qs[0]}”", giver=giver))
  ks = e["kills"]
  where_kill = at(e["at"])
  if e.get("first"):
    out.append(pick(FIRSTKIND, "first", e["first"]).format(foes=e["first"], at=where_kill))
    where_kill = "there"
  if len(ks) == 1:
    out.append(pick(KILLS["one"], "k", e["level"]).format(n=words(ks[0][2]).capitalize() if False else words(ks[0][2]), foes=ks[0][1], at=where_kill))
  else:
    out.append(pick(KILLS["two"], "k", e["level"]).format(n1=words(ks[0][2]), foes1=ks[0][1], n2=words(ks[1][2]), foes2=ks[1][1], at=where_kill))
  if e.get("rare"):
    out.append(pick(RARE, "rare", e["rare"]).format(foe=e["rare"], at=at(e["at"])))
  if e.get("close"):
    foe, hp = e["close"]
    kind = "deep" if hp <= 10 else "light"
    out.append(pick(CLOSE[kind], "close", e["level"]).format(foe=foe, foe_cap=foe[0].upper() + foe[1:], hp=hp, at="there" if e["at"] == last[0] else at(e["at"])))
  if e.get("train"):
    out.append(pick(TRAIN, "train", e["train"]).format(s=e["train"], city=e.get("city", "Kharanos")))
  if e.get("loot"):
    out.append(pick(LOOT, "loot", e["loot"]).format(item=e["loot"], item_cap=e["loot"][0].upper() + e["loot"][1:]))
  long = e["level"] >= 6
  out.append(pick(CLOSE_CH["long" if long else "short"], "end", e["level"]).format(time=e["time"], gold=e["gold"]))
  text = cap(" ".join(out))
  return text[0].upper() + text[1:]

for e in L:
  print(f"## Level {e['level']}\n")
  print(chapter(e) + "\n")
