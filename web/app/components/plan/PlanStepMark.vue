<script setup lang="ts">
import type { PlanStepStatus } from '~/types/plan';

// The round mark before a step in the plan of a chat (Figma FEDDIES 1363:2683, 1363:2839, 1363:2842; iOS PlanStepMark):
// done is a full circle with a tick, the step you are on a grey ring with its first quarter filled in, and a step still
// to do (or skipped) a grey ring.
defineProps<{
  status: PlanStepStatus;
}>();

const RING = 'M19 10C19 14.9706 14.9706 19 10 19C5.02944 19 1 14.9706 1 10C1 5.02944 5.02944 1 10 1';
const QUARTER =
  'M19 10C19 8.8181 18.7672 7.64778 18.3149 6.55585C17.8626 5.46392 17.1997 4.47177 16.364 3.63604C15.5282 2.80031 14.5361 2.13738 13.4442 1.68508C12.3522 1.23279 11.1819 1 10 1';
const TICK =
  'M13.8379 6.06733C13.9182 6.12618 13.974 6.21768 13.9929 6.3217C14.0119 6.42572 13.9924 6.53374 13.9389 6.62201L9.57026 13.8221C9.54037 13.8713 9.50092 13.9126 9.45475 13.943C9.40859 13.9734 9.35685 13.9922 9.30327 13.9981C9.2497 14.0039 9.19562 13.9966 9.14492 13.9766C9.09423 13.9567 9.04819 13.9247 9.01011 13.8829L6.09771 10.6829C6.0334 10.607 5.99839 10.5067 6.00006 10.4031C6.00172 10.2995 6.03993 10.2006 6.10663 10.1273C6.17333 10.054 6.26331 10.012 6.35763 10.0102C6.45194 10.0084 6.54322 10.0469 6.61223 10.1175L9.21058 12.9725L13.3331 6.17773C13.3867 6.08956 13.47 6.0284 13.5647 6.0077C13.6594 5.98699 13.7576 6.00845 13.8379 6.06733Z';
</script>

<template>
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true" class="shrink-0">
    <template v-if="status === 'done'">
      <rect x="1" y="1" width="18" height="18" rx="9" class="fill-brand" />
      <path :d="TICK" fill-rule="evenodd" clip-rule="evenodd" class="fill-white" />
      <path :d="RING" class="stroke-brand" stroke-width="2" />
      <path :d="QUARTER" class="stroke-brand" stroke-width="2" />
    </template>
    <template v-else>
      <path :d="RING" class="stroke-step-ring" stroke-width="2" />
      <path :d="QUARTER" :class="status === 'active' ? 'stroke-brand' : 'stroke-step-ring'" stroke-width="2" />
    </template>
  </svg>
</template>
