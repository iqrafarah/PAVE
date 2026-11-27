<script setup lang="ts">
import type { NotificationEntry, NotificationSection } from '~/types/notifications';

// The inbox list (iOS NotificationsScreen): "Actie nodig" with its count first, then Vandaag, Deze week and Eerder.
// Arrow up and down move between notifications, Enter opens.
defineProps<{
  sections: NotificationSection[];
  selectedId: string | null;
}>();

const emit = defineEmits<{
  open: [entry: NotificationEntry];
  action: [entry: NotificationEntry, action: 'read' | 'delete'];
}>();

const STEPS: Record<string, number> = { ArrowDown: 1, ArrowUp: -1 };
const rootRef = useTemplateRef<HTMLElement>('root');

function moveFocus(event: KeyboardEvent) {
  const step = STEPS[event.key];
  if (!step) return;
  const rows = Array.from(rootRef.value?.querySelectorAll<HTMLButtonElement>('[data-notification-row]') ?? []);
  const index = rows.findIndex((row) => row.contains(document.activeElement));
  const next = rows[Math.min(Math.max(index + step, 0), rows.length - 1)];
  if (!next) return;
  event.preventDefault();
  next.focus();
}
</script>

<template>
  <nav ref="root" :aria-label="NOTIFICATIONS_LIST" class="flex flex-col gap-4" @keydown="moveFocus">
    <section v-for="section in sections" :key="section.title" :aria-label="section.title">
      <h3 :class="section.needsAction ? 'text-brand' : 'text-subtle'" class="mb-1 flex items-center gap-1.5 px-3 text-xs font-medium">
        {{ section.title }}
        <span v-if="section.needsAction" class="flex h-5 min-w-5 items-center justify-center rounded-full bg-brand px-1.75 text-xs text-white">
          {{ section.entries.length }}
        </span>
      </h3>
      <ul class="flex flex-col gap-0.5">
        <li v-for="entry in section.entries" :key="entry.notification.id">
          <NotificationRow
            :entry="entry"
            :is-selected="entry.ids.includes(selectedId ?? '')"
            @open="emit('open', entry)"
            @action="emit('action', entry, $event)"
          />
        </li>
      </ul>
    </section>
  </nav>
</template>
