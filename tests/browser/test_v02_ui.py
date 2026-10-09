#!/usr/bin/env python3
"""Браузерный (Chromium) тест v0.2: модели всех 10 видов, карточки видов (ПК/телефон), камера в доме, Ночь Искр,
глава 2, друзья, звук в настройках; панели на телефоне в альбомной ориентации не перекрывают трекер и прыжок.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_v02_ui.py [--shots DIR]
Скриншоты: docs/screens/2x_*.png"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *

SHOTS = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

EMOJI = re.compile('[\U0001F300-\U0001FAFF\u2600-\u27BF]')
CAM = "(([y,p,d])=>{const c=R2W.ENV.cam; c.yaw=y; c.pitch=p; c.dist=d;})"
SPECIES = ['Dog', 'Cat', 'Rabbit', 'Parrot', 'Fox', 'SnowLeopard', 'CorgiKnight', 'CrystalRabbit', 'Raccoon', 'Owl']
HOUSE = ('tp:-6,-46,180', [0.8, 0.45, 14])
LAWN = 'tp:92,150,0'

def boot(page, g, url, country):
    page.goto(url + 'index.html?persist=0&seed=1&country=' + country)
    g.wait(lambda: g.vis('[data-n="Hud"] [data-n="Status"]'), timeout=120, what='hud')
    g.vwait(2)
    g.cmd('species:Dog'); g.vwait(1)
    if g.vis('[data-n="Skip"]'): g.click('[data-n="Skip"]'); g.vwait(0.5)
    g.cmd('clock:10')

def rect(page, sel):
    return page.evaluate("""(q)=>{const e=document.querySelector(q); if(!e) return null; const s=getComputedStyle(e);
      if(s.display==='none'||s.visibility==='hidden') return null; const r=e.getBoundingClientRect();
      return r.width>0&&r.height>0 ? [r.left,r.top,r.right,r.bottom] : null;}""", sel)

def overlap(a, b):
    return a and b and a[0] < b[2] - 1 and b[0] < a[2] - 1 and a[1] < b[3] - 1 and b[1] < a[3] - 1

# тексты карточек не вылезают за карточку (обрезка, которую чинили в v0.2)
CLIP = """(q)=>{const out=[]; for(const card of document.querySelectorAll(q)){const c=card.getBoundingClientRect();
  if(c.width===0) continue;
  for(const e of card.querySelectorAll('*')){ if(![...e.childNodes].some(n=>n.nodeType===3&&n.textContent.trim())) continue;
    const s=getComputedStyle(e); if(s.display==='none'||s.visibility==='hidden') continue; const r=e.getBoundingClientRect();
    if(r.width===0) continue;
    if(r.left<c.left-2||r.right>c.right+2||r.top<c.top-2||r.bottom>c.bottom+2) out.push(card.dataset.n+'/'+(e.dataset.n||e.tagName));}}
  return out;}"""

def species_cards(page, g, label):
    g.cmd('ui:Species'); g.wait(lambda: g.vis('[data-n="SpeciesPanel"]'), what='species panel ' + label)
    g.vwait(0.8)
    for sp in ('Cat', 'Dog', 'Rabbit', 'Parrot'):
        check('%s: карточка %s' % (label, sp), page.locator('[data-n="SpeciesPanel"] [data-n="%s"]' % sp).count() > 0)
    clipped = page.evaluate(CLIP, '[data-n="SpeciesPanel"] [data-n="Cat"], [data-n="SpeciesPanel"] [data-n="Dog"], '
                                  '[data-n="SpeciesPanel"] [data-n="Rabbit"], [data-n="SpeciesPanel"] [data-n="Parrot"]')
    check('%s: текст карточек не обрезан' % label, not clipped, clipped[:5])

with serve('/tmp/gw_ui') as url:
    # ---------- ПК 1280×720 ----------
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        boot(page, g, url, 'RU')
        # 1) модели всех 10 видов крупным планом (HUD скрыт)
        g.cmd('hud:off')
        for sp in SPECIES:
            g.cmd('morph:' + sp); g.vwait(1.2); g.cmd(LAWN)
            page.evaluate(CAM, [2.6, 0.25, 5.5]); g.vwait(1.6)
            g.shot('2x_pet_' + sp)
        check('модели 10 видов: ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0)
        g.cmd('morph:Dog'); g.vwait(1); g.cmd('hud:on')
        # 2) карточки видов (ПК)
        species_cards(page, g, 'ПК')
        g.shot('2x_species_cards_pc_1280x720')
        g.click('[data-n="SpeciesPanel"] [data-n="Close"]'); g.vwait(0.4)
        # 3) камера в доме: отдаление ограничено, стены между камерой и питомцем полупрозрачные
        g.cmd(HOUSE[0]); page.evaluate(CAM, HOUSE[1]); g.vwait(2.5)
        d = page.evaluate('R2W.ENV.cam.maxDist')
        check('дом: камера не отдаляется дальше 16', d is not None and d <= 16.5, d)
        g.shot('2x_house_camera')
        # 4) Ночь Искр
        g.cmd('level:50'); g.cmd('fasttrack:Fox'); g.vwait(0.5)
        g.cmd('ui:SparkNight'); g.wait(lambda: g.vis('[data-n="SparkNightPanel"]'), what='rebirth panel')
        g.vwait(0.8)
        check('Ночь Искр: карточка лисы', page.locator('[data-n="SparkNightPanel"] [data-n="Fox"]').count() > 0)
        check('Ночь Искр: кнопка «Переродиться» у лисы', g.vis('[data-n="SparkNightPanel"] [data-n="Fox"] [data-n="Reborn"]'))
        check('Ночь Искр: ускорение (Studio) скрыто вне Studio', not g.vis('[data-n="SparkNightPanel"] [data-n="Dev"]'))
        g.shot('2x_rebirth_pc')
        page.evaluate("document.querySelector('[data-n=\"SparkNightPanel\"] [data-n=\"Scroll\"]')?.scrollBy(0, 420)")
        g.vwait(0.5); g.shot('2x_rebirth_pc_species')
        g.cmd('ui:SparkNight'); g.vwait(0.4)
        # 5) глава 2
        g.cmd('chapter:c2_meet'); g.cmd('cut:Chapter2'); g.vwait(1.4); g.shot('2x_chapter2_cutscene')
        if g.vis('[data-n="Skip"]'): g.click('[data-n="Skip"]'); g.vwait(0.5)
        g.cmd('tp:-70,-14,180'); page.evaluate(CAM, [0.35, 0.3, 16]); g.vwait(2.5); g.shot('2x_chapter2_neighbours')
        tr = g.text('[data-n="Hud"] [data-n="Tracker"]')
        check('трекер: глава 2', '2' in tr, tr)
        g.cmd('chapter:c2_choice')
        g.click('[data-n="Hud"] [data-n="QuestsButton"]'); g.wait(lambda: g.vis('[data-n="QuestsPanel"]'), what='quests c2')
        g.vwait(0.6); g.shot('2x_chapter2_quests')
        g.click('[data-n="Hud"] [data-n="QuestsButton"]'); g.vwait(0.3)
        g.cmd('ui:Choice'); g.wait(lambda: g.vis('[data-n="ChoicePanel"]'), what='choice')
        g.vwait(0.6); g.shot('2x_chapter2_choice')
        g.cmd('ui:Choice'); g.vwait(0.3)
        g.cmd('tp:0,10,0'); page.evaluate(CAM, [3.0, 0.35, 22]); g.vwait(2.5); g.shot('2x_chapter2_party')
        # 6) друзья
        g.cmd('friendsfake'); g.vwait(0.5)
        g.click('[data-n="Hud"] [data-n="FriendsButton"]'); g.wait(lambda: g.vis('[data-n="FriendsPanel"]'), what='friends')
        g.vwait(0.8)
        check('друзья: заявка с кнопкой «Принять»', g.vis('[data-n="FriendsPanel"] [data-n="Req_90003"] [data-n="Accept"]'))
        check('друзья: игрок на сервере — «Добавить»', g.vis('[data-n="FriendsPanel"] [data-n="Here_90003"] [data-n="Add"]'))
        check('друзья: друг на сервере — «В гости»', g.vis('[data-n="FriendsPanel"] [data-n="Here_90005"] [data-n="Visit"]'))
        check('друзья: сохранённый друг не в сети', g.vis('[data-n="FriendsPanel"] [data-n="Friend_90001"]'))
        check('друзья: список комбо', g.vis('[data-n="FriendsPanel"] [data-n="Combo_HappyDance"]'))
        g.shot('2x_friends_pc')
        g.click('[data-n="Hud"] [data-n="FriendsButton"]'); g.vwait(0.3)
        # 7) звук: настройки, переключатель «Звуки» глушит группу SFX
        g.click('[data-n="Hud"] [data-n="SettingsButton"]'); g.wait(lambda: g.vis('[data-n="SettingsPanel"]'), what='settings')
        g.vwait(0.5)
        t0 = g.text('[data-n="SettingsPanel"] [data-n="SfxToggle"]')
        g.click('[data-n="SettingsPanel"] [data-n="SfxToggle"]'); g.vwait(1)
        t1 = g.text('[data-n="SettingsPanel"] [data-n="SfxToggle"]')
        check('звук: переключатель «Звуки»', t0 != t1, (t0, t1))
        g.shot('2x_settings_sound')
        g.click('[data-n="SettingsPanel"] [data-n="SfxToggle"]'); g.vwait(0.6)
        g.click('[data-n="Hud"] [data-n="SettingsButton"]'); g.vwait(0.3)
        check('в интерфейсе нет эмодзи', not EMOJI.search(page.evaluate('document.body.innerText')))
        check('ПК: ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))
        check('ПК: в консоли нет ошибок', not errs, errs[:3])
        bad = [l for l in g.logs if 'UIDRIVER FAIL' in l]
        check('команды тестового драйвера выполнены', not bad, bad[:3])
    # ---------- телефон: портрет и альбом ----------
    for (w, h) in [(390, 844), (844, 390)]:
        with browser(w, h, True) as ctx:
            page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
            boot(page, g, url, 'US')
            species_cards(page, g, '%dx%d' % (w, h))
            g.shot('2x_species_cards_phone_%dx%d' % (w, h))
            g.click('[data-n="SpeciesPanel"] [data-n="Close"]'); g.vwait(0.4)
            g.cmd('friendsfake'); g.vwait(0.3)
            for name, btn in (('Friends', 'FriendsButton'), ('Quests', 'QuestsButton'), ('Settings', 'SettingsButton')):
                g.click('[data-n="Hud"] [data-n="%s"]' % btn)
                g.wait(lambda: g.vis('[data-n="%sPanel"]' % name), what=name + ' phone')
                g.vwait(0.6)
                p = rect(page, '[data-n="%sPanel"]' % name)
                check('%dx%d: панель %s в пределах экрана' % (w, h, name),
                      p and p[0] >= -1 and p[1] >= -1 and p[2] <= w + 1 and p[3] <= h + 1, p)
                if w > h:
                    tr = rect(page, '[data-n="Hud"] [data-n="Tracker"]')
                    jb = rect(page, '[title="Jump"]')
                    check('%dx%d: панель %s не закрывает трекер' % (w, h, name), not overlap(p, tr), (p, tr))
                    check('%dx%d: панель %s не закрывает прыжок' % (w, h, name), not overlap(p, jb), (p, jb))
                if name == 'Friends':
                    g.shot('2x_friends_phone_%dx%d' % (w, h))
                g.click('[data-n="%sPanel"] [data-n="Close"]' % name); g.vwait(0.4)
            check('%dx%d: ошибок эмулятора нет' % (w, h), page.evaluate('R2W.ENV.errorCount') == 0)

print('\n%d ok, %d failed %s' % (oks, len(fails), fails))
sys.exit(1 if fails else 0)
