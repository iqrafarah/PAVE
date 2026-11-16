<script setup lang="ts">
import type { VaultItem } from '~/types/vault';

// An item in the vault as a tile in the grid or a row in the list, like iOS VaultLibraryCard. The round image is the
// logo (or else the cover), and its strongest colour tints the card: the band in the grid, a fade from the top left in
// the list (Figma 1348:9). A cover photo shows only in the band of the grid. Clicking the card opens everything about
// the item; the … button is the web version of the long press on iOS.
const props = defineProps<{
  item: VaultItem;
  isGrid: boolean;
}>();

const emit = defineEmits<{
  open: [];
  action: [id: 'edit' | 'confirm' | 'delete'];
}>();

const place = computed(() => itemPlace(props.item));
const period = computed(() => itemPeriod(props.item));
const monogramName = computed(() => props.item.organisationName ?? props.item.title);
const shownSkills = computed(() => props.item.skills.slice(0, props.isGrid ? 1 : 2));
const hiddenSkills = computed(() => props.item.skills.length - shownSkills.value.length);

// The colour of the logo; until it is known, or without one, the colour of the category. The list has no band for the
// cover, so without a logo its fade takes the colour of the cover (as on iOS).
const logoTint = useImageTint(() => props.item.logoUrl);
const coverTint = useImageTint(() => (props.isGrid || props.item.logoUrl ? null : props.item.coverUrl));
const tint = computed(
  () => logoTint.value ?? coverTint.value ?? `var(--color-${CATEGORY_TINTS[props.item.category].replace('bg-', '')})`,
);
const hasCoverFailed = ref(false);
const coverUrl = computed(() => (hasCoverFailed.value ? null : props.item.coverUrl));
watch(
  () => props.item.coverUrl,
  () => (hasCoverFailed.value = false),
);

</script>

<template>
  <div class="group relative flex w-full">
    <button
      type="button"
      :style="isGrid ? undefined : { background: `linear-gradient(to bottom right, ${tint} 0%, white 55%)` }"
      class="relative flex w-full overflow-hidden rounded-2xl border border-card-line bg-white text-left transition-shadow hover:shadow-[0_2px_10px_rgb(0_0_0/0.07)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      :class="isGrid ? 'flex-col' : 'items-center gap-3.5 p-3.5 pr-12'"
      @click="emit('open')"
    >
      <!-- Grid: the band (cover, or the logo's colour) with the status on it and the logo over its edge. -->
      <template v-if="isGrid">
        <span :style="{ background: tint }" class="relative h-12 w-full shrink-0 overflow-hidden" aria-hidden="true">
          <img v-if="coverUrl" :src="coverUrl" alt="" class="size-full object-cover" loading="lazy" @error="hasCoverFailed = true" />
        </span>
        <VaultStatusBadge :status="item.status" class="absolute right-2 top-2" />
        <VaultLogo :name="monogramName" :logo-url="item.logoUrl" :size="44" class="absolute left-3 top-6.5" />
        <span class="flex flex-1 flex-col gap-2 px-3 pb-3 pt-7.5">
          <span class="line-clamp-2 break-words pr-7 text-[0.9375rem]/snug font-semibold text-heading">{{ item.title }}</span>
          <span class="flex flex-col gap-1 text-[0.8125rem] font-medium text-heading">
            <span v-if="place" class="flex items-start gap-2">
              <VaultIcon src="/images/vault/building.svg" class="mt-px size-4.5 text-subtle" />
              <span class="line-clamp-2">{{ place }}</span>
            </span>
            <span v-if="period" class="flex items-center gap-2">
              <VaultIcon src="/images/vault/calendar.svg" class="size-4.5 text-subtle" />
              {{ period }}
            </span>
          </span>
          <span v-if="item.skills.length" class="mt-auto flex flex-wrap gap-1.5 pt-1">
            <VaultSkillChip v-for="skill in shownSkills" :key="skill" :text="skill" />
            <VaultSkillChip v-if="hiddenSkills > 0" :text="`+${hiddenSkills}`" :label="VAULT_MORE_SKILLS(hiddenSkills)" />
          </span>
        </span>
      </template>

      <!-- List: the logo in its circle, the details beside it, on a fade of the logo's colour. -->
      <template v-else>
        <VaultLogo :name="monogramName" :logo-url="item.logoUrl" :size="56" />
        <span class="flex min-w-0 flex-1 flex-col gap-1.5">
          <span class="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span class="min-w-0 text-base font-semibold text-heading">{{ item.title }}</span>
            <VaultStatusBadge :status="item.status" />
          </span>
          <span class="flex flex-wrap gap-x-5 gap-y-1 text-[0.8125rem] font-medium text-heading">
            <span v-if="place" class="flex min-w-0 items-center gap-2">
              <VaultIcon src="/images/vault/building.svg" class="size-4.5 text-subtle" />
              <span class="truncate">{{ place }}</span>
            </span>
            <span v-if="period" class="flex items-center gap-2">
              <VaultIcon src="/images/vault/calendar.svg" class="size-4.5 text-subtle" />
              {{ period }}
            </span>
          </span>
          <span v-if="item.skills.length" class="flex flex-wrap gap-1.5 pt-0.5">
            <VaultSkillChip v-for="skill in shownSkills" :key="skill" :text="skill" />
            <VaultSkillChip v-if="hiddenSkills > 0" :text="`+${hiddenSkills}`" :label="VAULT_MORE_SKILLS(hiddenSkills)" />
          </span>
        </span>
      </template>
    </button>

    <!-- Shown on hover and keyboard focus; always on touch screens, which have no hover. No transform here: it would
         tie the floating list to this spot and let the next card cover it. -->
    <div
      :class="isGrid ? 'right-1.5 top-13.5' : 'inset-y-0 right-2 my-auto h-8'"
      class="absolute rounded-lg bg-white/90 opacity-0 transition-opacity group-hover:opacity-100 focus-within:opacity-100 has-[[aria-expanded=true]]:opacity-100 [@media(hover:none)]:opacity-100"
    >
      <VaultItemMenu :item="item" @select="emit('action', $event)" />
    </div>
  </div>
</template>
