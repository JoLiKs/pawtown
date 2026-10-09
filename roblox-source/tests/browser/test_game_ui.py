#!/usr/bin/env python3
"""Браузерный (Chromium) тест Pawtown: Luau -> roblox2web -> эмулятор, клики по настоящему интерфейсу.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_game_ui.py [--shots DIR]
Печатает OK/FAIL, сохраняет скриншоты (по умолчанию docs/screens)."""
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

CYR = re.compile('[А-Яа-яЁё]')
EMOJI = re.compile('[\U0001F300-\U0001FAFF\u2600-\u27BF]')

def ui_layout(page, w, h, label, tap=36, font=12):
    r = page.evaluate("""([w,h,tap,font])=>{
      const vis=e=>{const s=getComputedStyle(e); const r=e.getBoundingClientRect(); return s.visibility!=='hidden'&&s.display!=='none'&&r.width>0&&r.height>0&&+s.opacity>0.05;};
      const out=[], small=[], tiny=[];
      for(const n of ['Status','Needs','Tracker','Menu','Abilities']){
        const e=document.querySelector('[data-n="Hud"] [data-n="'+n+'"]'); if(!e||!vis(e)) continue; const r=e.getBoundingClientRect();
        if(r.left<-1||r.top<-1||r.right>w+1||r.bottom>h+1) out.push(n+':'+[r.left,r.top,r.right,r.bottom].map(Math.round));
      }
      for(const e of document.querySelectorAll('[data-n="Hud"] [data-n$="Button"]')){
        if(!vis(e)) continue; const r=e.getBoundingClientRect(); if(Math.min(r.width,r.height)<tap-0.5) small.push(e.dataset.n+':'+Math.round(r.width)+'x'+Math.round(r.height));
      }
      for(const e of document.querySelectorAll('[data-n="Hud"] *')){
        if(!vis(e)||![...e.childNodes].some(c=>c.nodeType===3&&c.textContent.trim())) continue;
        const fs=parseFloat(getComputedStyle(e).fontSize)*(e.getBoundingClientRect().height/Math.max(1,e.offsetHeight)); if(fs<font-0.3) tiny.push((e.dataset.n||e.tagName)+':'+fs.toFixed(1));
      }
      return {out, small, tiny};}""", [w, h, tap, font])
    check('%s: HUD в пределах экрана' % label, not r['out'], r['out'])
    check('%s: кнопки HUD >= %d px' % (label, tap), not r['small'], r['small'])
    check('%s: текст HUD >= %d px' % (label, font), not r['tiny'], r['tiny'][:6])

def boot(page, g, url, country):
    page.goto(url + 'index.html?persist=0&seed=1&country=' + country)
    g.wait(lambda: g.vis('[data-n="Hud"] [data-n="Status"]'), timeout=120, what='hud')
    g.vwait(2)

CAM = "(([y,p,d])=>{const c=R2W.ENV.cam; c.yaw=y; c.pitch=p; c.dist=d;})"
HOUSE = ('tp:0,-50', [0, 0.5, 24])
STREET = ('tp:-40,6', [0, 0.38, 18])
PARK = ('tp:110,120', [3.1416, 0.4, 30])
def go(page, g, spot, wait=2.5):
    g.cmd(spot[0]); page.evaluate(CAM, spot[1]); g.vwait(wait)

AUTOPLAY = """()=>{const seen=new WeakSet(); const key=(t)=>window.dispatchEvent(new KeyboardEvent(t,{code:'Space',key:' '}));
  const tick=()=>{const tg=document.querySelector('[data-n="TrickGame"] [data-n="Target"]'); if(!tg) return;
    const res=document.querySelector('[data-n="TrickGame"] [data-n="Result"]'); if(res&&getComputedStyle(res).display!=='none'&&res.getBoundingClientRect().width>0) return;
    const t=tg.getBoundingClientRect(), cx=t.left+t.width/2;
    for(const n of document.querySelectorAll('[data-n="TrickGame"] [data-n="Note"]')){const r=n.getBoundingClientRect();
      if(!seen.has(n)&&r.left+r.width/2-cx<8){seen.add(n); key('keydown'); setTimeout(()=>key('keyup'),30); break;}}
    requestAnimationFrame(tick);}; requestAnimationFrame(tick);}"""

def body_text(page):
    return page.evaluate("document.body.innerText")

with serve('/tmp/gw_ui') as url:
    # ---------- ПК 1280×720, русский клиент ----------
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        boot(page, g, url, 'RU')
        check('загрузка без ошибок эмулятора', page.evaluate('R2W.ENV.errorCount') == 0)
        check('трекер главы виден', g.vis('[data-n="Hud"] [data-n="Tracker"]'))
        check('русский язык по стране (RU)', bool(CYR.search(g.text('[data-n="Hud"] [data-n="Tracker"]'))), g.text('[data-n="Hud"] [data-n="Tracker"]'))
        check('до выбора вида меню скрыто', not g.vis('[data-n="Hud"] [data-n="Menu"]'))
        g.shot('01_shelter_start')
        # выбор вида — по-настоящему кнопкой «Выбрать»
        g.cmd('ui:Species'); g.wait(lambda: g.vis('[data-n="SpeciesPanel"]'), what='species panel')
        for sp in ('Cat', 'Dog', 'Rabbit', 'Parrot'):
            check('карточка вида ' + sp, g.vis('[data-n="SpeciesPanel"] [data-n="%s"]' % sp))
        check('редкие виды — «скоро»', g.vis('[data-n="SpeciesPanel"] [data-n="Rare"]'))
        g.vwait(0.5); g.shot('02_species_choice')
        g.click('[data-n="SpeciesPanel"] [data-n="Dog"] [data-n="Choose"]')
        g.wait(lambda: g.vis('[data-n="Cutscene"]') or g.vis('[data-n="Skip"]'), what='adoption cutscene')
        check('после выбора — заставка, окно выбора закрыто', not g.vis('[data-n="SpeciesPanel"]'))
        g.vwait(1); g.shot('03_adoption_cutscene')
        g.click('[data-n="Skip"]'); g.vwait(1)
        check('после выбора меню HUD видно', g.vis('[data-n="Hud"] [data-n="Menu"]'))
        # дом
        g.cmd('clock:10'); go(page, g, HOUSE)
        g.shot('04_house')
        # улица
        go(page, g, STREET)
        g.shot('05_maple_street')
        # парк
        go(page, g, PARK)
        g.shot('06_dandelion_park')
        # мини-игра «Трюки»
        go(page, g, HOUSE, 1)
        g.cmd('ui:Tricks'); g.wait(lambda: g.vis('[data-n="TricksPanel"]'), what='tricks panel')
        g.vwait(0.5); g.shot('07_tricks_list')
        g.click('[data-n="TricksPanel"] [data-n="Sit"] [data-n="Play"]')
        g.wait(lambda: g.vis('[data-n="TrickGame"] [data-n="Box"]'), what='trick game')
        page.wait_for_timeout(900)
        g.shot('08_trick_game')
        # «игрок»: жмёт Пробел, когда лапка подлетает к кругу (rAF в странице — точнее, чем опрос из Python)
        page.evaluate(AUTOPLAY)
        g.wait(lambda: g.vis('[data-n="TrickGame"] [data-n="Result"]'), what='trick result')
        g.vwait(0.6); g.shot('09_trick_result')
        check('итог трюка показан с медалью', g.vis('[data-n="TrickGame"] [data-n="Medal"]'))
        acc = g.text('[data-n="TrickGame"] [data-n="Score"]')
        check('нажатия в такт засчитываются (>= 45 %)', any(int(x) >= 45 for x in re.findall(r'\d+', acc)), acc)
        g.click('[data-n="TrickGame"] [data-n="CloseResult"]'); g.vwait(0.5)
        # журнал заданий
        g.click('[data-n="Hud"] [data-n="QuestsButton"]')
        g.wait(lambda: g.vis('[data-n="QuestsPanel"]'), what='quests')
        g.vwait(0.6); g.shot('10_quests')
        daily = sorted(set(n for n in g.names('[data-n="QuestsPanel"]') if n.startswith('d_')))
        check('журнал: 5 ежедневных заданий', len(daily) == 5, daily)
        g.click('[data-n="Hud"] [data-n="QuestsButton"]'); g.vwait(0.3)
        # магазин
        g.click('[data-n="Hud"] [data-n="ShopButton"]')
        g.wait(lambda: g.vis('[data-n="ShopPanel"]'), what='shop')
        g.vwait(0.6); g.shot('11_shop')
        g.click('[data-n="Hud"] [data-n="ShopButton"]'); g.vwait(0.3)
        # ванна
        g.cmd('ui:Bath'); g.wait(lambda: g.vis('[data-n="BathGame"] [data-n="Spot1"]'), what='bath')
        g.vwait(0.5); g.shot('12_bath')
        g.click('[data-n="BathGame"] [data-n="Cancel"]'); g.vwait(0.5)
        # сон-воспоминание и ночь
        g.cmd('cut:Dream'); g.vwait(1.2); g.shot('13_dream')
        g.click('[data-n="Skip"]'); g.vwait(0.5)
        g.cmd('clock:22'); go(page, g, STREET); g.shot('14_street_night')
        g.cmd('clock:10'); go(page, g, HOUSE, 1.5)
        g.shot('15_hud_pc_1280x720')
        ui_layout(page, 1280, 720, 'ПК 1280×720', tap=36)
        check('в интерфейсе нет эмодзи', not EMOJI.search(body_text(page)))
        check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))
        check('в консоли нет ошибок', not errs, errs[:3])
        bad = [l for l in g.logs if 'UIDRIVER FAIL' in l]
        check('команды тестового драйвера выполнены', not bad, bad[:3])
    # ---------- телефон: портрет и альбом, английский клиент ----------
    for (w, h) in [(390, 844), (844, 390)]:
        with browser(w, h, True) as ctx:
            page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
            boot(page, g, url, 'US')
            check('%dx%d: английский по стране (US)' % (w, h), not CYR.search(g.text('[data-n="Hud"] [data-n="Tracker"]')))
            g.cmd('species:Cat'); g.vwait(1)
            if g.vis('[data-n="Skip"]'): g.click('[data-n="Skip"]')
            g.cmd('clock:10'); go(page, g, HOUSE)
            g.shot('16_hud_phone_%dx%d' % (w, h))
            ui_layout(page, w, h, 'телефон %dx%d' % (w, h))
            g.click('[data-n="Hud"] [data-n="QuestsButton"]')
            g.wait(lambda: g.vis('[data-n="QuestsPanel"]'), what='quests phone')
            g.vwait(0.6); g.shot('17_quests_phone_%dx%d' % (w, h))
            check('%dx%d: ошибок эмулятора нет' % (w, h), page.evaluate('R2W.ENV.errorCount') == 0)

print('\n%d ok, %d failed %s' % (oks, len(fails), fails))
sys.exit(1 if fails else 0)
