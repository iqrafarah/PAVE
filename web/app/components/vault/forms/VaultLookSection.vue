<script setup lang="ts">
import type { VaultItemCategory, VaultMenuOption } from '~/types/vault';

// How the evidence looks on its card, with the card shown live on top (iOS VaultLookSection, Figma 1167:12237): a
// logo for the round avatar, and a card with or without a cover. Without a cover the band takes the strongest colour of
// the logo; with one it shows your own photo. A chosen picture opens "Verplaatsen en schalen" first, and can be moved
// again later. Used for adding and for changing evidence; the parent keeps the files.
const props = defineProps<{
  // What to show now: a picked file (as a temporary link) or the saved picture.
  logoUrl: string | null;
  coverUrl: string | null;
  title: string;
  organisationName: string;
  category: VaultItemCategory | '';
  // The organisation's own logo is on the card and wins over one you add.
  hasOrganisationLogo?: boolean;
  // A logo of your own is chosen; the circle may also show the cover when there is none.
  hasLogo: boolean;
  problem?: string | null;
}>();

const wantsCover = defineModel<boolean>('wantsCover', { required: true });

const emit = defineEmits<{
  pick: [role: 'logo' | 'cover', file: File];
  remove: [role: 'logo' | 'cover'];
}>();

type Role = 'logo' | 'cover';

const logoInputRef = useTemplateRef<HTMLInputElement>('logoInput');
const coverInputRef = useTemplateRef<HTMLInputElement>('coverInput');
const fileProblem = ref<string | null>(null);
const groupId = useId();
const problemId = useId();
// The picture being moved and scaled, and each picture as chosen, so moving it again never loses what was cut off.
const framing = ref<{ role: Role; image: File | Blob } | null>(null);
const originals = ref<Partial<Record<Role, File | Blob>>>({});

const OPTIONS = [
  { value: false, label: VAULT_NO_COVER, image: '/images/vault/no-cover-example.png' },
  { value: true, label: VAULT_COVER, image: '/images/vault/cover-example.png' },
];

const LOGO_ACTIONS: VaultMenuOption[] = [
  { id: 'reframe', label: VAULT_REFRAME, icon: '/images/vault/icons/PencilOutline.svg' },
  { id: 'replace', label: VAULT_LOGO_REPLACE, icon: '/images/vault/icons/PhotoOutline.svg' },
  { id: 'remove', label: VAULT_LOGO_REMOVE, icon: '/images/vault/icons/TrashOutline.svg' },
];
const COVER_ACTIONS: VaultMenuOption[] = [
  { id: 'reframe', label: VAULT_REFRAME, icon: '/images/vault/icons/PencilOutline.svg' },
  { id: 'replace', label: VAULT_COVER_REPLACE, icon: '/images/vault/icons/PhotoOutline.svg' },
  { id: 'remove', label: VAULT_COVER_REMOVE, icon: '/images/vault/icons/TrashOutline.svg' },
];

const tint = useImageTint(() => (props.hasLogo || props.hasOrganisationLogo ? props.logoUrl : null));
const band = computed(
  () => tint.value ?? (props.category ? `var(--color-${CATEGORY_TINTS[props.category].replace('bg-', '')})` : 'var(--color-tint)'),
);
const previewTitle = computed(() => props.title.trim() || (props.category ? VAULT_CATEGORY_TITLES[props.category] : VAULT_ADD_TITLE));
const monogramName = computed(() => props.organisationName || props.title || '?');
const shownCover = computed(() => (wantsCover.value ? props.coverUrl : null));

/** A chosen picture goes to "Verplaatsen en schalen" first; only what you keep there is used. */
function take(role: Role, file: File | undefined) {
  if (!file) return;
  const problem = checkVaultFile(file, 'cover');
  fileProblem.value = problem;
  if (problem) return;
  originals.value[role] = file;
  framing.value = { role, image: file };
}

function handleInput(role: Role, event: Event) {
  const input = event.target as HTMLInputElement;
  take(role, input.files?.[0]);
  input.value = '';
}

/** Moves the picture again: the one chosen just now, or else the saved one, fetched from the vault. */
async function reframe(role: Role) {
  fileProblem.value = null;
  const original = originals.value[role];
  if (original) {
    framing.value = { role, image: original };
    return;
  }
  const url = role === 'logo' ? props.logoUrl : props.coverUrl;
  if (!url) return;
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(String(response.status));
    const image = await response.blob();
    originals.value[role] = image;
    framing.value = { role, image };
  } catch {
    fileProblem.value = VAULT_IMAGE_UNREADABLE;
  }
}

function useFramed(file: File) {
  if (!framing.value) return;
  emit('pick', framing.value.role, file);
  framing.value = null;
}

/** The browser cannot show the picture (HEIC): it is used as it is, without moving it. */
function useUnframed() {
  const current = framing.value;
  framing.value = null;
  if (current?.image instanceof File) emit('pick', current.role, current.image);
  else fileProblem.value = VAULT_IMAGE_UNREADABLE;
}

function handleAction(role: Role, action: string) {
  if (action === 'reframe') reframe(role);
  else if (action === 'replace') (role === 'logo' ? logoInputRef : coverInputRef).value?.click();
  else {
    delete originals.value[role];
    emit('remove', role);
  }
}
</script>

<template>
  <div class="flex flex-col gap-6">
    <input ref="logoInput" type="file" :accept="VAULT_COVER_ACCEPT" class="sr-only" tabindex="-1" aria-hidden="true" @change="handleInput('logo', $event)" />
    <input ref="coverInput" type="file" :accept="VAULT_COVER_ACCEPT" class="sr-only" tabindex="-1" aria-hidden="true" @change="handleInput('cover', $event)" />

    <!-- The top of the card as it will look in the vault, live while you choose. -->
    <div class="relative overflow-hidden rounded-2xl border border-card-line bg-white" aria-hidden="true">
      <div class="h-16 transition-colors duration-300" :style="{ background: band }">
        <img v-if="shownCover" :src="shownCover" alt="" class="size-full object-cover" />
      </div>
      <VaultLogo :name="monogramName" :logo-url="logoUrl" :size="60" class="absolute left-4 top-8.5" />
      <p class="truncate px-4 pb-3.5 pt-10 text-base font-medium text-heading">{{ previewTitle }}</p>
    </div>

    <!-- Logo: the circle is the button. -->
    <section class="flex items-center gap-3.5">
      <VaultLogo v-if="hasOrganisationLogo" :name="monogramName" :logo-url="logoUrl" :size="64" />
      <VaultMenu
        v-else-if="hasLogo"
        :label="VAULT_LOGO"
        :options="LOGO_ACTIONS"
        toggle-class="flex rounded-full hover:opacity-85 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @select="handleAction('logo', $event)"
      >
        <template #label>
          <VaultLogo :name="monogramName" :logo-url="logoUrl" :size="64" />
          <span class="sr-only">{{ VAULT_LOGO }}</span>
        </template>
      </VaultMenu>
      <button
        v-else
        type="button"
        :aria-label="VAULT_LOGO_CHOOSE"
        :title="VAULT_LOGO_CHOOSE"
        class="flex size-16 shrink-0 items-center justify-center rounded-full border-[1.5px] border-dashed border-drop-line bg-drop text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        @click="logoInputRef?.click()"
      >
        <VaultIcon src="/images/vault/icons/Plus.svg" class="size-6" />
      </button>
      <div class="flex min-w-0 flex-1 flex-col gap-1">
        <h3 class="text-base font-semibold text-heading">{{ VAULT_LOGO }}</h3>
        <p class="text-xs font-medium text-subtle">
          {{ hasOrganisationLogo ? VAULT_LOGO_FROM_ORGANISATION : hasLogo ? VAULT_LOGO_HINT_CHOSEN : VAULT_LOGO_HINT }}
        </p>
      </div>
    </section>

    <!-- Cover -->
    <section class="flex flex-col gap-3">
      <h3 :id="groupId" class="text-base font-semibold text-heading">{{ VAULT_COVER }}</h3>
      <div role="radiogroup" :aria-labelledby="groupId" class="grid grid-cols-2 gap-3">
        <label
          v-for="option in OPTIONS"
          :key="option.label"
          :class="wantsCover === option.value ? 'border-brand bg-drop' : 'border-field-line bg-white hover:bg-surface'"
          class="relative flex cursor-pointer flex-col items-center rounded-xl border-[1.5px] px-3 pb-3 pt-3 has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand"
        >
          <input v-model="wantsCover" type="radio" :value="option.value" name="vault-cover" class="sr-only" />
          <img :src="option.image" alt="" width="100" height="80" class="h-20 w-25 rounded-t-[0.625rem] object-cover" />
          <span class="mt-2.5 text-xs font-semibold text-heading">{{ option.label }}</span>
        </label>
      </div>

      <template v-if="wantsCover">
        <div v-if="coverUrl" class="flex items-center gap-3 rounded-xl bg-tint py-2.5 pl-3 pr-1">
          <img :src="coverUrl" alt="" class="h-11 w-22 rounded-lg object-cover" />
          <span class="flex min-w-0 flex-1 flex-col gap-0.5">
            <span class="text-sm font-semibold text-heading">{{ VAULT_COVER }}</span>
            <span class="text-xs font-medium text-subtle">{{ VAULT_COVER_CHOSEN }}</span>
          </span>
          <VaultMenu
            :label="VAULT_COVER_ACTIONS"
            :options="COVER_ACTIONS"
            align="right"
            toggle-class="flex size-11 items-center justify-center rounded-lg text-heading hover:bg-white focus-visible:outline-2 focus-visible:outline-brand"
            @select="handleAction('cover', $event)"
          >
            <template #label>
              <VaultIcon src="/images/vault/icons/Ellipsis.svg" class="size-5" />
              <span class="sr-only">{{ VAULT_COVER_ACTIONS }}</span>
            </template>
          </VaultMenu>
        </div>
        <VaultDropZone
          v-else
          kind="cover"
          is-compact
          :described-by="fileProblem || problem ? problemId : undefined"
          @pick="take('cover', $event)"
          @problem="fileProblem = $event"
        />
      </template>
      <p v-else class="text-xs font-medium text-subtle">{{ hasLogo ? VAULT_NO_COVER_WITH_LOGO : VAULT_NO_COVER_WITHOUT_LOGO }}</p>
      <p v-if="fileProblem || problem" :id="problemId" role="alert" class="text-xs text-danger">{{ fileProblem ?? problem }}</p>
    </section>

    <VaultImageFramer
      :image="framing?.image ?? null"
      :shape="framing?.role === 'cover' ? 'band' : 'circle'"
      @use="useFramed"
      @close="framing = null"
      @unreadable="useUnframed"
    />
  </div>
</template>
