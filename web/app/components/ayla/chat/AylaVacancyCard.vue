<script setup lang="ts">
import type { Vacancy } from '~/types/ayla';

const props = defineProps<{
  vacancy: Vacancy;
}>();

const hasLogoFailed = ref(false);

const companyLine = computed(() => getCompanyLine(props.vacancy));
const employmentText = computed(() => getEmploymentText(props.vacancy.employment));
const salaryText = computed(() => (props.vacancy.salary ? formatMonthlySalary(props.vacancy.salary) : null));
const showsLogo = computed(() => Boolean(props.vacancy.logoUrl) && !hasLogoFailed.value);
const isExample = computed(() => props.vacancy.source === 'example');
</script>

<template>
  <article class="flex gap-3 rounded-2xl border border-line bg-white p-4">
    <img
      v-if="showsLogo"
      :src="vacancy.logoUrl"
      alt=""
      class="size-12 shrink-0 rounded-full border border-line object-contain"
      @error="hasLogoFailed = true"
    />
    <span
      v-else
      class="flex size-12 shrink-0 items-center justify-center rounded-full border border-line bg-white text-lg font-bold text-brand"
      aria-hidden="true"
    >
      {{ getMonogram(vacancy.company) }}
    </span>

    <div class="min-w-0 flex-1">
      <p v-if="isExample" class="mb-1 text-xs font-medium text-warning">{{ AYLA_EXAMPLE_LABEL }}</p>
      <h3 class="text-base font-semibold text-ink">{{ vacancy.title }}</h3>
      <ul class="mt-2 space-y-1.5 text-sm text-muted">
        <li class="flex items-center gap-2">
          <LayoutIcon name="building" />
          <span class="sr-only">Bedrijf:</span>
          {{ companyLine }}
        </li>
        <li v-if="employmentText" class="flex items-center gap-2">
          <LayoutIcon name="briefcase" />
          <span class="sr-only">Uren:</span>
          {{ employmentText }}
        </li>
        <li v-if="salaryText" class="flex items-center gap-2">
          <LayoutIcon name="euro" />
          <span class="sr-only">Salaris:</span>
          {{ salaryText }}
        </li>
      </ul>

      <div v-if="vacancy.skillGap.length" class="mt-3">
        <p class="text-sm font-medium text-ink">{{ AYLA_SKILL_GAP }}</p>
        <ul class="mt-1.5 space-y-1.5">
          <li
            v-for="gap in vacancy.skillGap"
            :key="gap.skill"
            class="rounded-lg bg-tint px-3 py-1.5 text-sm"
          >
            <span class="font-medium text-brand">{{ gap.skill }}</span>
            <span class="block text-xs text-muted">{{ gap.requirement }}</span>
          </li>
        </ul>
      </div>

      <a
        v-if="vacancy.url"
        :href="vacancy.url"
        target="_blank"
        rel="noopener noreferrer"
        class="mt-3 inline-flex items-center gap-1.5 text-sm font-medium text-brand underline hover:text-ink focus-visible:outline-2 focus-visible:outline-brand"
      >
        {{ AYLA_OPEN_VACANCY }}
        <LayoutIcon name="external" />
        <span class="sr-only">(opent in een nieuw tabblad)</span>
      </a>
    </div>
  </article>
</template>
