<script setup>
import { FolderIcon, MapIcon, UserIcon, CheckBadgeIcon, AcademicCapIcon, ChatBubbleLeftEllipsisIcon, WrenchScrewdriverIcon, Squares2X2Icon, ListBulletIcon, MagnifyingGlassIcon, PlusIcon, BuildingOffice2Icon, CalendarDaysIcon, ArrowUpIcon } from "@heroicons/vue/24/outline"
const folders = [
  { name: 'Certificaten', icon: CheckBadgeIcon },
  { name: 'Diploma’s', icon: AcademicCapIcon },
  { name: 'Feedback', icon: ChatBubbleLeftEllipsisIcon },
  { name: 'Projecten', icon: WrenchScrewdriverIcon },
]
const items = [
  { title: 'HAVO Diploma', status: 'Geverifieerd', organization: 'Mgr. Frencken College Oosterhout', date: '2020 - 2025', initials: 'MFC', color: 'peach', category: 'Diploma’s', tags: [] },
  { title: 'Leidinggevende', status: 'Verifiëren', organization: 'Plus Laurijssen Oosterhout', date: 'Nov 2025 - Present (11 mos)', initials: 'PLUS', color: 'green', category: 'Feedback', tags: ['Leiderschap', 'Communicatie', '+2'] },
  { title: 'Eindverslag stage', status: 'Afgewezen', organization: 'LiveWall Tilburg', date: 'Mar 2025 - Dec 2025', initials: 'L', color: 'lime', category: 'Projecten', tags: ['Verkoop', 'Vulmanagement', '+1'] },
]
const activeFolder = ref('')
const search = ref('')
const showSearch = ref(false)
const visibleItems = computed(() => items.filter(item => (!activeFolder.value || item.category === activeFolder.value) && `${item.title} ${item.organization}`.toLowerCase().includes(search.value.toLowerCase())))
</script>

<template>
  <div class="shell">
    <aside class="rail" aria-label="Hoofdnavigatie">
      <NuxtLink to="/" class="logo" aria-label="PAVE home"><img src="/images/vault-icons/pave.svg" alt=""></NuxtLink>
      <NuxtLink to="/" class="rail-icon active" aria-label="Ayla"><img src="/images/vault-icons/ayla-nav.svg" alt=""></NuxtLink>
      <span class="rail-icon" aria-label="Kluis" aria-current="page"><FolderIcon class="ui-icon" aria-hidden="true" /></span>
      <span class="rail-icon" aria-label="Kaart"><MapIcon class="ui-icon" aria-hidden="true" /></span>
      <span class="rail-icon" aria-label="Profiel"><UserIcon class="ui-icon" aria-hidden="true" /></span>
    </aside>
    <main class="vault">
      <header class="heading"><img src="/images/vault-icons/ayla.svg" alt=""> Ayla</header>
      <section class="folders" aria-label="Mappen">
        <button v-for="folder in folders" :key="folder.name" class="folder" :aria-pressed="activeFolder === folder.name" @click="activeFolder = activeFolder === folder.name ? '' : folder.name">
          <span class="folder-top"><span class="folder-symbol"><component :is="folder.icon" class="folder-glyph" aria-hidden="true" /></span></span>
          <span class="folder-info"><strong>{{ folder.name }}</strong><span>8 items</span></span>
        </button>
      </section>
      <div class="toolbar">
        <div class="filters"><button class="selected" @click="activeFolder = ''">Alle</button><button disabled>Status</button><button disabled>Bron</button><button disabled>Datum</button></div>
        <div class="actions"><button class="square" disabled aria-label="Rasterweergave"><Squares2X2Icon class="ui-icon" aria-hidden="true" /></button><button class="square selected-view" aria-label="Lijstweergave"><ListBulletIcon class="ui-icon" aria-hidden="true" /></button><button class="square" aria-label="Zoeken" @click="showSearch = !showSearch"><MagnifyingGlassIcon class="ui-icon" aria-hidden="true" /></button><button class="secondary" disabled><PlusIcon class="ui-icon" aria-hidden="true" /> Folder aanmaken</button><button class="primary" disabled><PlusIcon class="ui-icon" aria-hidden="true" /> Toevoegen</button></div>
      </div>
      <input v-if="showSearch" v-model="search" class="search" type="search" placeholder="Zoeken in de kluis" aria-label="Zoeken in de kluis">
      <section class="items" aria-label="Bewijsstukken">
        <article v-for="item in visibleItems" :key="item.title" class="item">
          <div class="item-logo" :class="item.color"><span>{{ item.initials }}</span></div>
          <div class="item-content"><div class="item-heading"><strong>{{ item.title }}</strong><span class="status" :class="item.status === 'Geverifieerd' ? 'verified' : item.status === 'Verifiëren' ? 'pending' : 'rejected'">● {{ item.status }}</span></div><div class="details"><span><BuildingOffice2Icon class="detail-icon" aria-hidden="true" /> {{ item.organization }}</span><span><CalendarDaysIcon class="detail-icon" aria-hidden="true" /> {{ item.date }}</span><div class="tags"><span v-for="tag in item.tags" :key="tag">{{ tag }}</span></div></div></div>
        </article>
        <p v-if="!visibleItems.length" class="empty">Geen items gevonden.</p>
      </section>
      <div class="chat-dock"><div class="chat-title"><FolderIcon class="ui-icon" aria-hidden="true" /> Kluis</div><div class="chat-input"><PlusIcon class="ui-icon" aria-hidden="true" /><img src="/images/vault-icons/ayla.svg" alt=""><span class="placeholder">Vraag het aan Ayla</span><button disabled aria-label="Versturen"><ArrowUpIcon class="ui-icon" aria-hidden="true" /></button></div></div>
    </main>
  </div>
</template>

<style scoped>
.shell{min-height:100vh;display:flex;background:#fff;color:#292929;font-family:Arial,sans-serif;font-size:14px}.rail{width:72px;flex:0 0 72px;background:#f8f8f8;border-right:1px solid #eee;display:flex;align-items:center;flex-direction:column;gap:14px;padding:13px 0}.logo,.rail-icon{display:grid;place-items:center;border-radius:8px}.logo{width:51px;height:49px;background:#e9eeea;margin-bottom:12px}.logo img{width:43px}.rail-icon{width:41px;height:38px;background:#f1f1f1}.rail-icon img{width:24px;height:24px}.rail-icon.active{background:#355d4c}.vault{flex:1;min-width:0;padding:30px 42px 150px}.heading{display:flex;align-items:center;gap:6px;color:#355d4c;font-size:30px;font-weight:700;margin:0 0 48px}.heading img{height:32px;width:20px}.folders{display:grid;grid-template-columns:repeat(4,minmax(150px,1fr));gap:20px}.folder{padding:0;border:1px solid #ebedeb;border-radius:12px;overflow:hidden;background:white;text-align:left;cursor:pointer}.folder[aria-pressed=true]{outline:2px solid #355d4c}.folder-top{display:flex;align-items:flex-end;height:90px;background:#e9eeea;padding-left:20px}.folder-top img{width:90px;height:70px;transform:translateY(10px)}.folder-info{display:flex;flex-direction:column;gap:6px;padding:22px 22px 20px}.folder-info strong{font-size:15px;font-weight:500}.folder-info span{color:#888}.toolbar{display:flex;align-items:center;justify-content:space-between;gap:16px;margin:40px 0 35px}.filters,.actions{display:flex;align-items:center;gap:10px}.filters button,.actions button{border:0;border-radius:7px;cursor:pointer}.filters button{background:transparent;padding:10px;font-size:15px}.filters .selected{background:#e9eeea}.actions button{height:40px}.square{width:40px;background:#f7f7f7;font-size:21px}.square img{width:24px;height:24px;margin:auto}.selected-view,.primary{background:#355d4c;color:white}.secondary{background:#f7f7f7;padding:0 14px}.primary{display:flex;align-items:center;padding:0 12px}.primary img{width:20px}button:disabled{cursor:default}.search{margin:-20px 0 20px;padding:10px;border:1px solid #ddd;border-radius:7px;width:280px}.items{display:grid;gap:14px}.item{display:flex;min-height:102px;border:1px solid #ebedeb;border-radius:14px;overflow:hidden}.item-logo{width:100px;flex:none;display:grid;place-items:center}.item-logo span{display:grid;place-items:center;border-radius:50%;background:white;color:#355d4c;width:62px;height:62px;font-weight:800;font-size:16px}.peach{background:#ffe3bf}.green{background:#dceccb}.green span{background:#80bd24;color:white}.lime{background:#eff8c9}.lime span{background:#151515;color:#b3e724;font-size:30px}.item-content{padding:20px 22px;flex:1;min-width:0}.item-heading{display:flex;align-items:center;gap:12px}.item-heading strong{font-size:17px}.status{font-size:12px;padding:4px 7px;border-radius:5px}.verified{background:#e9f3ed;color:#355d4c}.pending{background:#fff1dd;color:#967337}.rejected{background:#fce5e3;color:#a54848}.details{display:flex;align-items:center;gap:36px;margin-top:14px}.tags{margin-left:auto;display:flex;gap:8px}.tags span{background:#f2f3f4;padding:6px 9px;border-radius:5px;font-size:11px}.empty{color:#777}.chat-dock{position:fixed;bottom:30px;left:calc(72px + (100% - 72px)/2);transform:translateX(-50%);width:min(608px,calc(100% - 110px));border-radius:35px;background:#e9eeea;padding:10px}.chat-title{font-weight:600;font-size:12px;padding:0 30px 8px}.chat-title img{display:inline-block;width:20px;height:20px;vertical-align:middle}.chat-input{height:53px;background:#fff;border-radius:26px;display:flex;align-items:center;gap:12px;padding:0 12px;font-size:22px}.chat-input img{width:12px;height:20px}.placeholder{flex:1;font-size:13px;color:#bbb}.chat-input button{border:0;border-radius:50%;width:30px;height:30px;color:#fff;background:#355d4c}@media(max-width:900px){.folders{grid-template-columns:repeat(2,1fr)}.toolbar{flex-wrap:wrap}.details{flex-wrap:wrap;gap:10px}.tags{margin-left:0}}@media(max-width:600px){.rail{width:52px;flex-basis:52px}.vault{padding:24px 16px 150px}.heading{margin-bottom:24px}.folders{gap:10px}.actions{flex-wrap:wrap}.chat-dock{left:calc(52px + (100% - 52px)/2)}.item-logo{width:65px}.item-logo span{width:45px;height:45px}.item-content{padding:14px}}

.ui-icon { width: 24px; height: 24px; flex: none; }
.rail-icon .ui-icon { width: 24px; height: 24px; }
.folder-symbol { display: grid; place-items: center; width: 82px; height: 64px; position: relative; transform: translateY(10px); background: #355d4c; border-radius: 9px; color: white; }
.folder-symbol:before { content: ""; position: absolute; width: 32px; height: 8px; top: -5px; left: 0; background: #355d4c; border-radius: 6px 6px 0 0; }
.folder-glyph { width: 30px; height: 30px; }
.square .ui-icon { margin: auto; }
.secondary { display: flex; align-items: center; gap: 4px; }
.secondary .ui-icon, .primary .ui-icon, .chat-title .ui-icon { width: 20px; height: 20px; }
.chat-title .ui-icon, .detail-icon { display: inline-block; vertical-align: middle; }
.detail-icon { width: 20px; height: 20px; }
.chat-input button .ui-icon { width: 20px; height: 20px; margin: auto; }
</style>
