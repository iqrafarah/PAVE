<script setup lang="ts">
import type { FairInvitation } from '~/composables/notifications/useFairInvitations';

// Meldingen › Van de beurs (iOS NotificationFairSection and FairInvitationRow): an employer at the fair invites you for a
// talk. When, their message, and your answer; once you said yes, the talk can go in your calendar. Folds away, and
// remembers that in this browser.
const STORAGE_KEY = 'pave-meldingen-fair-collapsed';

const fair = useFairInvitations();
const isCollapsed = ref(false);
const problem = ref<string | null>(null);
const listId = useId();

onMounted(() => {
  fair.load();
  try {
    isCollapsed.value = localStorage.getItem(STORAGE_KEY) === '1';
  } catch {
    // Without storage it simply starts open.
  }
});

watch(isCollapsed, (collapsed) => {
  try {
    localStorage.setItem(STORAGE_KEY, collapsed ? '1' : '0');
  } catch {
    // Remembering is a convenience only.
  }
});

async function answer(invitation: FairInvitation, accepted: boolean) {
  problem.value = null;
  const { error } = await fair.answer(invitation.id, accepted);
  problem.value = error;
}

function icsDate(date: Date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

function icsText(value: string) {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/[,;]/g, (match) => `\\${match}`)
    .replace(/\n/g, '\\n');
}

/** An .ics file of the talk (an hour), which every calendar app opens. */
function calendarFile(invitation: FairInvitation) {
  if (!invitation.invitedFor) return null;
  const start = new Date(invitation.invitedFor);
  const end = new Date(start.getTime() + 60 * 60 * 1000);
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//PAVE//Meldingen//NL',
    'BEGIN:VEVENT',
    `UID:${invitation.id}@pave`,
    `DTSTAMP:${icsDate(new Date())}`,
    `DTSTART:${icsDate(start)}`,
    `DTEND:${icsDate(end)}`,
    `SUMMARY:${icsText(FAIR_CALENDAR_TITLE(invitation.employerName))}`,
    `DESCRIPTION:${icsText(`${invitation.vacancyTitle}. ${FAIR_CALENDAR_NOTES}`)}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return `data:text/calendar;charset=utf-8,${encodeURIComponent(lines.join('\r\n'))}`;
}

const secondaryButton =
  'flex min-h-10 flex-1 items-center justify-center gap-1.5 rounded-field bg-field-line px-3 text-sm font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const primaryButton =
  'flex min-h-10 flex-1 items-center justify-center rounded-field bg-brand px-3 text-sm font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
</script>

<template>
  <section v-if="fair.shown.value.length" :aria-label="FAIR_SECTION_TITLE">
    <NotificationSectionHeader v-model:collapsed="isCollapsed" :title="FAIR_SECTION_TITLE" :count="fair.shown.value.length" :controls="listId" />
    <ul v-show="!isCollapsed" :id="listId" class="mt-1 flex flex-col gap-2">
      <li v-for="invitation in fair.shown.value" :key="invitation.id" class="flex flex-col gap-2.5 rounded-xl border border-card-line bg-white p-3">
        <div class="flex items-start gap-3">
          <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-tint text-brand" aria-hidden="true">
            <VaultIcon src="/images/vault/calendar.svg" class="size-4.5" />
          </span>
          <div class="flex min-w-0 flex-col gap-0.5">
            <p class="text-sm font-semibold text-heading">{{ FAIR_INVITED_FOR(invitation.vacancyTitle) }}</p>
            <p class="text-xs text-subtle">{{ invitation.employerName }}</p>
            <p v-if="invitation.invitedFor" class="text-sm font-medium text-brand">{{ fairSlot(invitation.invitedFor) }}</p>
          </div>
        </div>
        <p v-if="invitation.message" class="text-xs text-subtle">“{{ invitation.message }}”</p>
        <div v-if="invitation.answer === null" class="flex gap-2">
          <button type="button" :class="secondaryButton" @click="answer(invitation, false)">{{ FAIR_DECLINE }}</button>
          <button type="button" :class="primaryButton" @click="answer(invitation, true)">{{ FAIR_ACCEPT }}</button>
        </div>
        <template v-else-if="invitation.answer === 'accepted'">
          <p class="text-xs font-medium text-brand">{{ FAIR_ACCEPTED }}</p>
          <a
            v-if="calendarFile(invitation)"
            :href="calendarFile(invitation)!"
            :download="`${FAIR_CALENDAR_TITLE(invitation.employerName)}.ics`"
            :class="secondaryButton"
          >
            <VaultIcon src="/images/vault/calendar.svg" class="size-4" />
            {{ FAIR_TO_CALENDAR }}
          </a>
        </template>
        <p v-else class="text-xs font-medium text-subtle">{{ FAIR_DECLINED }}</p>
      </li>
    </ul>
    <p v-if="problem" role="alert" class="mt-2 px-3 text-xs text-danger">{{ problem }}</p>
  </section>
</template>
