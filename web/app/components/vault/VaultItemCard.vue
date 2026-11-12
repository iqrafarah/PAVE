<script setup lang="ts">
import type { RowMenuItem } from '~/types/ayla';
import type { VaultItem } from '~/types/vault';

// An item in the vault as a tile in the grid or a row in the list, compact like iOS VaultLibraryCard. Clicking it
// opens everything about the item. The … button is the web version of the long press on iOS: Aanpassen (also the
// folder it is in) and Verwijderen, without opening the item first.
const props = defineProps<{
  item: VaultItem;
  isGrid: boolean;
}>();

const emit = defineEmits<{
  open: [];
  action: [id: 'edit' | 'delete'];
}>();

const SHOWN_SKILLS = 2;
const place = computed(() => itemPlace(props.item));
const period = computed(() => itemPeriod(props.item));
const monogramName = computed(() => props.item.organisationName ?? props.item.title);
const shownSkills = computed(() => props.item.skills.slice(0, SHOWN_SKILLS));
const hiddenSkills = computed(() => props.item.skills.length - shownSkills.value.length);

// The colour comes from the logo, else the cover; until it is known (or without either) from the category.
const imageTint = useImageTint(() => props.item.logoUrl ?? props.item.coverUrl);
const tint = computed(() => (imageTint.value ? '' : CATEGORY_TINTS[props.item.category]));
const tintStyle = computed(() => (imageTint.value ? { background: imageTint.value } : undefined));
const hasCoverFailed = ref(false);
const coverUrl = computed(() => (hasCoverFailed.value ? null : props.item.coverUrl));
watch(
  () => props.item.coverUrl,
  () => (hasCoverFailed.value = false),
);

const ACTIONS: RowMenuItem[] = [
  { id: 'edit', label: VAULT_EDIT },
  { id: 'delete', label: VAULT_DELETE, isDanger: true },
];
</script>

<template>
  <div class="group relative flex w-full">
    <button
      type="button"
      :class="isGrid ? 'flex-col' : 'min-h-21 items-stretch'"
      class="relative flex w-full overflow-hidden rounded-2xl border border-card-line bg-white text-left transition-shadow hover:shadow-[0_2px_10px_rgb(0_0_0/0.07)] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
      @click="emit('open')"
    >
      <!-- Grid: the band (cover or colour) with the logo over its edge. -->
      <template v-if="isGrid">
        <span :class="tint" :style="tintStyle" class="relative h-14 w-full shrink-0 overflow-hidden" aria-hidden="true">
          <img v-if="coverUrl" :src="coverUrl" alt="" class="size-full object-cover" loading="lazy" @error="hasCoverFailed = true" />
        </span>
        <VaultLogo :name="monogramName" :logo-url="item.logoUrl" :size="52" class="absolute left-3.5 top-7" />
        <span class="flex flex-1 flex-col px-3.5 pb-3.5 pt-9">
          <span class="line-clamp-2 break-words text-base/snug font-semibold text-heading">{{ item.title }}</span>
          <VaultStatusBadge :status="item.status" class="mt-1.5 self-start" />
          <span class="mt-2.5 flex flex-col gap-1.5 text-[0.8125rem] font-medium text-heading">
            <span v-if="place" class="flex items-center gap-2">
              <VaultIcon src="/images/vault/building.svg" class="size-4.5 text-subtle" />
              <span class="truncate">{{ place }}</span>
            </span>
            <span v-if="period" class="flex items-center gap-2">
              <VaultIcon src="/images/vault/calendar.svg" class="size-4.5 text-subtle" />
              {{ period }}
            </span>
          </span>
          <span v-if="item.skills.length" class="mt-auto pt-3">
            <span class="flex flex-wrap gap-1.5 border-t border-card-line pt-3">
              <VaultSkillChip v-for="skill in shownSkills" :key="skill" :text="skill" />
              <VaultSkillChip v-if="hiddenSkills > 0" :text="`+${hiddenSkills}`" :label="VAULT_MORE_SKILLS(hiddenSkills)" />
            </span>
          </span>
        </span>
      </template>

      <!-- List: the coloured block with the logo on the left, the details beside it and the skills on the right. -->
      <template v-else>
        <span
          :class="tint"
          :style="tintStyle"
          class="relative flex w-18 shrink-0 items-center justify-center overflow-hidden"
          aria-hidden="true"
        >
          <img
            v-if="coverUrl"
            :src="coverUrl"
            alt=""
            class="absolute inset-0 size-full object-cover"
            loading="lazy"
            @error="hasCoverFailed = true"
          />
          <VaultLogo :name="monogramName" :logo-url="item.logoUrl" :size="44" class="relative" />
        </span>
        <span class="flex min-w-0 flex-1 flex-wrap items-center gap-x-5 gap-y-2 py-3 pl-4 pr-12">
          <span class="flex min-w-0 flex-1 flex-col gap-1">
            <span class="flex flex-wrap items-center gap-x-2.5 gap-y-1">
              <span class="min-w-0 text-base font-semibold text-heading">{{ item.title }}</span>
              <VaultStatusBadge :status="item.status" />
            </span>
            <span class="flex flex-wrap gap-x-5 gap-y-1 text-[0.8125rem] font-medium text-heading">
              <span v-if="place" class="flex min-w-0 items-center gap-2 lg:w-64">
                <VaultIcon src="/images/vault/building.svg" class="size-4.5 text-subtle" />
                <span class="truncate">{{ place }}</span>
              </span>
              <span v-if="period" class="flex items-center gap-2">
                <VaultIcon src="/images/vault/calendar.svg" class="size-4.5 text-subtle" />
                {{ period }}
              </span>
            </span>
          </span>
          <span v-if="item.skills.length" class="flex flex-wrap gap-1.5">
            <VaultSkillChip v-for="skill in shownSkills" :key="skill" :text="skill" />
            <VaultSkillChip v-if="hiddenSkills > 0" :text="`+${hiddenSkills}`" :label="VAULT_MORE_SKILLS(hiddenSkills)" />
          </span>
        </span>
      </template>
    </button>

    <!-- Shown on hover and keyboard focus; always on touch screens, which have no hover. -->
    <div
      :class="isGrid ? 'right-2 top-2' : 'right-2 top-1/2 -translate-y-1/2'"
      class="absolute rounded-lg bg-white/90 opacity-0 transition-opacity group-hover:opacity-100 focus-within:opacity-100 has-[[aria-expanded=true]]:opacity-100 [@media(hover:none)]:opacity-100"
    >
      <AylaRowMenu :items="ACTIONS" :label="VAULT_ITEM_ACTIONS(item.title)" @select="emit('action', $event as 'edit' | 'delete')" />
    </div>
  </div>
</template>
