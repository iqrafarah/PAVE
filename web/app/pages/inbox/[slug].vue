<script setup lang="ts">
// Werkgever-modus of the fair demo on any phone or laptop: who applied at this stand, and inviting them for a talk.
// The secret key comes in the link (?sleutel=…), printed on the employer's card.
definePageMeta({ layout: 'public' });
const route = useRoute();
const slug = String(route.params.slug ?? '');
const secret = String(route.query.sleutel ?? '');
const { inbox, problem, load, invite } = useFairInbox(slug, secret);
const inviting = ref<string | null>(null);
const moment = ref('');
const message = ref('');
const sending = ref(false);
const sendFailed = ref(false);
let timer: ReturnType<typeof setInterval> | undefined;

useHead(() => ({ title: inbox.value?.employer ? `${inbox.value.employer.name} · inbox · PAVE` : 'Inbox · PAVE' }));

const days: Record<string, string> = { maandag: 'ma', dinsdag: 'di', woensdag: 'wo', donderdag: 'do', vrijdag: 'vr', zaterdag: 'za', zondag: 'zo' };
const when = (date?: string) =>
  date ? new Intl.DateTimeFormat('nl-NL', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }).format(new Date(date)) : '';

function startInvite(id: string) {
  const start = new Date(Date.now() + 2 * 86_400_000);
  start.setHours(10, 0, 0, 0);
  const local = new Date(start.getTime() - start.getTimezoneOffset() * 60_000);
  moment.value = local.toISOString().slice(0, 16);
  message.value = '';
  sendFailed.value = false;
  inviting.value = id;
}

async function sendInvite() {
  if (!inviting.value || !moment.value) return;
  sending.value = true;
  const ok = await invite(inviting.value, new Date(moment.value), message.value);
  sending.value = false;
  if (ok) inviting.value = null;
  else sendFailed.value = true;
}

onMounted(() => {
  load();
  timer = setInterval(load, 10_000);
});
onBeforeUnmount(() => clearInterval(timer));
</script>

<template>
  <div class="flex flex-col gap-5">
    <LayoutEmptyState v-if="problem === 'wrong_key'" icon="briefcase" title="Geen toegang" message="Deze werkgeverssleutel klopt niet." />
    <LayoutEmptyState v-else-if="problem === 'failed' && !inbox" icon="briefcase" title="Niet geladen" message="De inbox kon niet worden geladen. Probeer het opnieuw." />
    <template v-else-if="inbox">
      <section>
        <p class="text-xs font-semibold uppercase tracking-wide text-brand">Werkgever-modus · demo</p>
        <h1 class="font-heading text-2xl font-semibold text-heading">{{ inbox.employer?.name }}</h1>
        <p class="text-sm text-subtle">Zo ziet de werkgever wie er bij de stand solliciteerde. In de demo speelt een medespeler de recruiter.</p>
      </section>
      <LayoutEmptyState v-if="!inbox.applications.length" icon="briefcase" title="Nog niemand" message="Laat iemand de poster of de stand scannen en snel solliciteren." />
      <article v-for="application in inbox.applications" :key="application.id" class="flex flex-col gap-2 rounded-2xl border border-card-border bg-panel p-5">
        <div class="flex items-center gap-3">
          <img v-if="application.photo" :src="application.photo" alt="" width="48" height="48" class="size-12 shrink-0 rounded-full object-cover" />
          <div v-else class="flex size-12 shrink-0 items-center justify-center rounded-full bg-tint text-brand" aria-hidden="true">
            <LayoutPaveIcon name="person" class="size-6" />
          </div>
          <div class="min-w-0">
            <h2 class="text-lg font-semibold text-ink break-words">{{ application.name || 'Sollicitant' }}</h2>
            <p class="text-sm text-subtle">{{ [application.headline, application.vacancyTitle].filter(Boolean).join(' · ') }}</p>
          </div>
        </div>
        <p v-if="application.why" class="text-base text-ink">{{ application.why }}</p>
        <p v-if="application.pitch" class="text-sm italic text-subtle">“{{ application.pitch }}”</p>
        <p v-if="application.availability.days.length || application.availability.maxHours" class="text-sm text-subtle">
          Kan op {{ application.availability.days.map((day) => days[day] ?? day).join(', ') }}<template v-if="application.availability.maxHours"> · max. {{ application.availability.maxHours }} uur</template>
        </p>
        <NuxtLink
          v-if="application.profileCode"
          :to="`/gedeeld/${application.profileCode}`"
          target="_blank"
          class="self-start rounded-full border border-brand px-4 py-2 text-sm font-semibold text-brand focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand"
        >Bekijk profiel en bewijs</NuxtLink>
        <p v-if="application.status === 'invited' && application.answer === 'accepted'" class="font-semibold text-brand">Komt op {{ when(application.invitedFor) }}</p>
        <p v-else-if="application.status === 'invited' && application.answer === 'declined'" class="font-semibold text-subtle">Kan niet op dat moment</p>
        <p v-else-if="application.status === 'invited'" class="text-sm text-subtle">Uitgenodigd voor {{ when(application.invitedFor) }}, wacht op antwoord</p>
        <template v-else>
          <form v-if="inviting === application.id" class="flex flex-col gap-3" @submit.prevent="sendInvite">
            <label class="flex flex-col gap-1 text-sm text-subtle" :for="`moment-${application.id}`">Wanneer
              <input :id="`moment-${application.id}`" v-model="moment" type="datetime-local" required class="rounded-xl border border-line bg-panel p-3 text-base text-ink" />
            </label>
            <label class="flex flex-col gap-1 text-sm text-subtle" :for="`message-${application.id}`">Bericht
              <textarea :id="`message-${application.id}`" v-model="message" rows="2" maxlength="400" placeholder="Bijvoorbeeld: meld je bij de servicebalie…" class="rounded-xl border border-line bg-panel p-3 text-base text-ink" />
            </label>
            <p v-if="sendFailed" class="text-sm text-critical" aria-live="polite">De uitnodiging kon niet worden verstuurd. Probeer het opnieuw.</p>
            <div class="flex gap-3">
              <button type="button" class="flex-1 rounded-full border border-line px-4 py-3 font-semibold text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand" @click="inviting = null">Annuleer</button>
              <button type="submit" :disabled="sending" class="flex-1 rounded-full bg-brand px-4 py-3 font-semibold text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60">{{ sending ? 'Versturen…' : 'Verstuur uitnodiging' }}</button>
            </div>
          </form>
          <button v-else type="button" class="rounded-full bg-brand px-4 py-3 font-semibold text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-brand" @click="startInvite(application.id)">Uitnodigen voor een gesprek</button>
        </template>
      </article>
    </template>
  </div>
</template>
