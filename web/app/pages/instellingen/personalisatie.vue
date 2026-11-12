<script setup lang="ts">
import type { TextSize, ThemeId, WorkMode } from '~/composables/usePersonalisation';

// Personalisatie (Figma FEDDIES 1393:5359): your profile photo, the theme colour, how the vault shows, the way of
// working and the size of the text. Everything but the photo belongs to this browser and works at once; the photo
// belongs to your account.
useHead({ title: `${PERSONAL_TITLE} - PAVE` });

const account = useAccount();
const personal = usePersonalisation();

const photoInputRef = useTemplateRef<HTMLInputElement>('photoInput');
const pickedPhoto = ref<File | null>(null);
const isSavingPhoto = ref(false);
const photoProblem = ref<string | null>(null);
const ids = { photo: useId(), theme: useId(), view: useId(), work: useId(), size: useId() };

const MAX_PHOTO_BYTES = 10 * 1024 * 1024;
const TEXT_SIZE_ICONS: Record<TextSize, string> = { small: 'h-3 w-2.75', normal: 'h-4 w-3.5', large: 'h-5 w-4.5' };

const fullName = computed(() => account.state.value.fullName);
const avatarUrl = computed(() => account.state.value.avatarUrl);
const initial = computed(() => fullName.value?.trim().charAt(0).toUpperCase() ?? '');

const theme = computed({
  get: () => personal.state.value.theme,
  set: (value: string) => personal.set({ theme: value as ThemeId }),
});
const vaultView = computed({
  get: () => (personal.state.value.isVaultGrid ? 'grid' : 'list'),
  set: (value: string) => personal.set({ isVaultGrid: value === 'grid' }),
});
const workMode = computed({
  get: () => personal.state.value.workMode,
  set: (value: string) => personal.set({ workMode: value as WorkMode }),
});
const textSize = computed({
  get: () => personal.state.value.textSize,
  set: (value: string) => personal.set({ textSize: value as TextSize }),
});

/** A chosen photo is moved and scaled in its circle first; only what is kept there is saved. */
function pickPhoto(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  photoProblem.value = null;
  if (!/^image\/(jpeg|png)$/.test(file.type) || file.size > MAX_PHOTO_BYTES) {
    photoProblem.value = PERSONAL_PHOTO_TYPE;
    return;
  }
  pickedPhoto.value = file;
}

async function savePhoto(photo: File) {
  pickedPhoto.value = null;
  isSavingPhoto.value = true;
  const problem = await account.setAvatar(photo);
  isSavingPhoto.value = false;
  photoProblem.value = problem === 'notReady' ? PERSONAL_PHOTO_NOT_READY : problem ? PERSONAL_PHOTO_FAILED : null;
}

async function removePhoto() {
  photoProblem.value = null;
  isSavingPhoto.value = true;
  const problem = await account.removeAvatar();
  isSavingPhoto.value = false;
  if (problem) photoProblem.value = PERSONAL_PHOTO_REMOVE_FAILED;
}

onMounted(() => {
  personal.load();
  account.load();
});

const heading = 'text-xl font-semibold text-heading';
const section = 'flex flex-col gap-5 border-b border-toolbar-line py-8 first:pt-0 last:border-b-0';
</script>

<template>
  <div class="min-h-0 flex-1 overflow-y-auto bg-white">
    <SettingsPageHeader :title="SETTINGS_TITLE" :back-to="SETTINGS_PATH" :back-label="PERSONAL_BACK" />

    <!-- Figma: one column of 706px, 14px between choices, a thin line between the parts. -->
    <div class="mx-auto flex w-full max-w-184.5 flex-col px-4 pb-16 pt-3">
      <h2 class="sr-only">{{ PERSONAL_TITLE }}</h2>

      <section :aria-labelledby="ids.photo" :class="section">
        <h3 :id="ids.photo" :class="heading">{{ PERSONAL_PHOTO }}</h3>
        <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
          <img v-if="avatarUrl" :src="avatarUrl" alt="" class="size-28.75 shrink-0 rounded-full bg-tint object-cover" />
          <span
            v-else
            class="flex size-28.75 shrink-0 items-center justify-center rounded-full bg-tint font-heading text-4xl font-semibold text-brand"
            aria-hidden="true"
          >
            <template v-if="initial">{{ initial }}</template>
            <LayoutPaveIcon v-else name="person" class="h-10 w-8" />
          </span>
          <div class="flex min-w-0 flex-1 flex-col gap-3.5">
            <div class="flex flex-wrap items-center gap-3">
              <input ref="photoInput" type="file" accept="image/jpeg,image/png" class="sr-only" tabindex="-1" aria-hidden="true" @change="pickPhoto" />
              <button
                type="button"
                :disabled="isSavingPhoto"
                class="min-h-10 min-w-26.75 rounded-full border border-heading px-5 text-base font-medium text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
                @click="photoInputRef?.click()"
              >
                {{ avatarUrl ? PERSONAL_PHOTO_CHANGE : PERSONAL_PHOTO_CHOOSE }}
              </button>
              <button
                v-if="avatarUrl"
                type="button"
                :disabled="isSavingPhoto"
                class="flex min-h-10 items-center gap-2 rounded-lg px-2.5 text-base font-medium text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
                @click="removePhoto"
              >
                <img src="/images/settings/trash.svg" alt="" width="18" height="18" />
                {{ PERSONAL_PHOTO_REMOVE }}
              </button>
            </div>
            <p class="text-[0.9375rem] font-medium text-subtle">{{ isSavingPhoto ? PERSONAL_PHOTO_SAVING : PERSONAL_PHOTO_HINT }}</p>
            <p v-if="photoProblem" role="alert" class="text-sm text-danger">{{ photoProblem }}</p>
          </div>
        </div>
      </section>

      <section :aria-labelledby="ids.theme" :class="section">
        <h3 :id="ids.theme" :class="heading">{{ PERSONAL_THEME }}</h3>
        <div role="radiogroup" :aria-labelledby="ids.theme" class="flex flex-wrap gap-3.5">
          <label
            v-for="option in PERSONAL_THEMES"
            :key="option.id"
            :title="option.name"
            :style="{ '--swatch': option.hex }"
            :class="theme === option.id ? 'border-(--swatch) p-1.25' : 'border-transparent p-0'"
            class="flex h-18.5 w-19 cursor-pointer rounded-full border transition-[padding] has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand motion-reduce:transition-none"
          >
            <input v-model="theme" type="radio" name="pave-theme" :value="option.id" class="sr-only" />
            <span class="flex-1 rounded-full bg-(--swatch)" aria-hidden="true" />
            <span class="sr-only">{{ option.name }}</span>
          </label>
        </div>
      </section>

      <section :aria-labelledby="ids.view" :class="section">
        <h3 :id="ids.view" :class="heading">{{ PERSONAL_VAULT_VIEW }}</h3>
        <div role="radiogroup" :aria-labelledby="ids.view" class="grid gap-3.5 sm:grid-cols-2">
          <SettingsChoice v-model="vaultView" name="pave-vault-view" value="list" :label="PERSONAL_VIEW_LIST">
            <VaultIcon src="/images/settings/list.svg" class="h-4.5 w-6" />
          </SettingsChoice>
          <SettingsChoice v-model="vaultView" name="pave-vault-view" value="grid" :label="PERSONAL_VIEW_GRID">
            <VaultIcon src="/images/settings/grid.svg" class="size-8.5" />
          </SettingsChoice>
        </div>
      </section>

      <section :aria-labelledby="ids.work" :class="section">
        <h3 :id="ids.work" :class="heading">{{ PERSONAL_WORK_MODE }}</h3>
        <div role="radiogroup" :aria-labelledby="ids.work" class="grid gap-3.5 sm:grid-cols-2">
          <SettingsChoice v-model="workMode" name="pave-work-mode" value="ai" :label="PERSONAL_WORK_AI" :meaning="PERSONAL_WORK_AI_MEANING">
            <VaultIcon src="/images/settings/sparkles.svg" class="size-6" />
          </SettingsChoice>
          <SettingsChoice
            v-model="workMode"
            name="pave-work-mode"
            value="traditional"
            :label="PERSONAL_WORK_TRADITIONAL"
            :meaning="PERSONAL_WORK_TRADITIONAL_MEANING"
          >
            <VaultIcon src="/images/settings/list.svg" class="h-4.5 w-6" />
          </SettingsChoice>
        </div>
      </section>

      <section :aria-labelledby="ids.size" :class="section">
        <h3 :id="ids.size" :class="heading">{{ PERSONAL_TEXT_SIZE }}</h3>
        <div role="radiogroup" :aria-labelledby="ids.size" class="grid gap-3.5 sm:grid-cols-3">
          <SettingsChoice
            v-for="option in PERSONAL_TEXT_SIZES"
            :key="option.id"
            v-model="textSize"
            name="pave-text-size"
            :value="option.id"
            :label="option.name"
            is-small
          >
            <span class="flex w-4.5 justify-center"><LayoutAylaGlyph :class="TEXT_SIZE_ICONS[option.id]" /></span>
          </SettingsChoice>
        </div>
        <p class="text-xs font-medium text-subtle">{{ PERSONAL_DEVICE_NOTE }}</p>
      </section>
    </div>

    <VaultImageFramer :image="pickedPhoto" shape="circle" @use="savePhoto" @close="pickedPhoto = null" @unreadable="pickedPhoto = null; photoProblem = PERSONAL_PHOTO_TYPE" />
  </div>
</template>
