<script setup lang="ts">
type StepStatus = 'done' | 'current' | 'upcoming';

const props = defineProps<{
  steps: string[];
  currentIndex: number;
}>();

const STATUS_TEXT: Record<StepStatus, string> = {
  done: '(klaar)',
  current: '(nu bezig)',
  upcoming: '',
};

const CIRCLE_CLASS: Record<StepStatus, string> = {
  done: 'border-brand bg-brand text-white',
  current: 'border-brand bg-brand text-white',
  upcoming: 'border-line bg-white text-muted',
};

const TITLE_CLASS: Record<StepStatus, string> = {
  done: 'text-muted',
  current: 'font-medium text-ink',
  upcoming: 'text-muted',
};

const items = computed(() =>
  props.steps.map((title, index) => {
    const status = getStatus(index);
    const isLineDone = index <= props.currentIndex;
    return {
      title,
      number: index + 1,
      status,
      circleClass: CIRCLE_CLASS[status],
      titleClass: TITLE_CLASS[status],
      lineClass: isLineDone ? 'before:bg-brand' : 'before:bg-line',
    };
  }),
);

function getStatus(index: number): StepStatus {
  if (index < props.currentIndex) return 'done';
  if (index === props.currentIndex) return 'current';
  return 'upcoming';
}
</script>

<template>
  <ol aria-label="Stappen" class="mb-6 flex">
    <li
      v-for="item in items"
      :key="item.title"
      :aria-current="item.status === 'current' ? 'step' : undefined"
      :class="item.lineClass"
      class="relative flex flex-1 flex-col items-center gap-1.5 text-center before:absolute before:right-1/2 before:top-2.75 before:h-0.5 before:w-full first:before:hidden"
    >
      <span
        :class="item.circleClass"
        class="relative z-10 flex size-6 items-center justify-center rounded-full border text-xs font-semibold"
        aria-hidden="true"
      >
        <svg
          v-if="item.status === 'done'"
          class="size-3.5"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="3"
          stroke="currentColor"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
        </svg>
        <template v-else>{{ item.number }}</template>
      </span>
      <span :class="item.titleClass" class="px-1 text-xs">
        {{ item.title }}
        <span class="sr-only">{{ STATUS_TEXT[item.status] }}</span>
      </span>
    </li>
  </ol>
</template>
