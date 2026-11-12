<script setup lang="ts">
useHead({ title: `${SETTINGS_ACCOUNT} - PAVE` });

const account = useAccount();
const { signOut } = useAuth();
const state = computed(() => account.state.value);
const name = ref('');
const nameId = useId();
const photoInputRef = useTemplateRef<HTMLInputElement>('photoInput');
const pickedPhoto = ref<File | null>(null);
const photoProblem = ref<string | null>(null);
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');
const removeRef = useTemplateRef<{ open: () => void }>('remove');
const isSigningOut = ref(false);
const signOutError = ref<string | null>(null);
const hasNameChanged = computed(() => name.value.trim().replace(/\s+/g, ' ') !== (state.value.preferredName ?? ''));
const details = computed(() => [
  { label: PERSONAL_FULL_NAME, value: state.value.legalName },
  { label: PERSONAL_EMAIL, value: state.value.email },
].filter((detail) => detail.value));

watch(() => state.value.preferredName, (value) => { name.value = value ?? ''; }, { immediate: true });

function pickPhoto(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;
  photoProblem.value = null;
  if (!['image/jpeg', 'image/png'].includes(file.type) || file.size > 5 * 1024 * 1024) {
    photoProblem.value = PERSONAL_PHOTO_TYPE;
    return;
  }
  pickedPhoto.value = file;
}

async function savePhoto(photo: File) {
  pickedPhoto.value = null;
  await account.setAvatar(photo);
}

function unreadablePhoto() {
  pickedPhoto.value = null;
  photoProblem.value = PERSONAL_PHOTO_TYPE;
}

async function confirmSignOut() {
  if (isSigningOut.value) return;
  signOutError.value = null;
  isSigningOut.value = true;
  try {
    const { error } = await signOut();
    if (error) signOutError.value = SETTINGS_SIGN_OUT_FAILED;
  } catch {
    signOutError.value = SETTINGS_SIGN_OUT_FAILED;
  } finally {
    isSigningOut.value = false;
  }
}

onMounted(account.load);
</script>

<template>
  <SettingsPage :title="SETTINGS_ACCOUNT">
    <div v-if="state.isLoading" role="status" class="rounded-pill bg-white p-4 text-sm text-subtle">Je gegevens laden…</div>
    <template v-else-if="state.isLoaded">
      <section :aria-label="PERSONAL_PHOTO" class="flex items-center gap-4 rounded-pill bg-white p-3">
        <SettingsAccountBadge :name="state.fullName" :avatar-url="state.avatarUrl" size="large" />
        <div class="flex min-w-0 flex-1 flex-col gap-2">
          <h2 class="truncate text-base font-semibold text-heading">{{ state.fullName ?? SETTINGS_YOUR_ACCOUNT }}</h2>
          <template v-if="state.canEdit">
            <div class="flex flex-wrap items-center gap-2">
              <input ref="photoInput" type="file" accept="image/jpeg,image/png" hidden @change="pickPhoto" />
              <button type="button" :disabled="state.isSaving" class="min-h-9 rounded-full border border-heading px-3.5 text-sm font-medium text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60" @click="photoInputRef?.click()">
                {{ state.avatarUrl ? PERSONAL_PHOTO_CHANGE : PERSONAL_PHOTO_CHOOSE }}
              </button>
              <button v-if="state.avatarPath" type="button" :disabled="state.isSaving" class="flex min-h-9 items-center gap-1 rounded-lg px-2 text-sm text-heading hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60" @click="removeRef?.open()">
                <LayoutPaveIcon name="trash" class="size-3.5" />
                {{ PERSONAL_PHOTO_REMOVE }}
              </button>
            </div>
            <p class="text-xs/normal text-subtle">{{ PERSONAL_PHOTO_HINT }}</p>
          </template>
          <p v-else class="text-xs/normal text-subtle">{{ PERSONAL_NOT_READY }}</p>
        </div>
      </section>
      <form class="flex flex-col gap-2 rounded-pill bg-white p-3" @submit.prevent="account.saveName(name)">
        <label :for="nameId" class="text-sm font-semibold text-heading">{{ PERSONAL_NAME }}</label>
        <div class="flex min-h-11.5 items-center gap-2 rounded-lg bg-surface px-3 focus-within:outline-2 focus-within:outline-brand">
          <input :id="nameId" v-model="name" :disabled="!state.canEdit || state.isSaving" :placeholder="state.legalName?.split(' ')[0] ?? PERSONAL_NAME_PROMPT" :aria-describedby="`${nameId}-hint`" autocomplete="nickname" maxlength="60" class="min-w-0 flex-1 bg-transparent py-3 text-base text-heading outline-none placeholder:text-subtle disabled:opacity-60" />
          <button v-if="hasNameChanged" type="submit" :disabled="!state.canEdit || state.isSaving" class="min-h-9 rounded-lg px-2 text-sm font-semibold text-brand focus-visible:outline-2 focus-visible:outline-brand disabled:opacity-60">{{ PERSONAL_SAVE }}</button>
        </div>
        <p :id="`${nameId}-hint`" class="text-xs/normal text-subtle">{{ PERSONAL_NAME_HINT }}</p>
      </form>
      <section v-if="details.length" :aria-label="SETTINGS_ACCOUNT_SUBTITLE" class="flex flex-col gap-2.5 rounded-pill bg-white p-3">
        <dl class="flex flex-col gap-2.5">
          <div v-for="detail in details" :key="detail.label">
            <dt class="text-xs text-subtle">{{ detail.label }}</dt>
            <dd class="break-words text-sm font-medium text-heading">{{ detail.value }}</dd>
          </div>
        </dl>
        <p class="text-xs/normal text-subtle">{{ PERSONAL_DETAILS_HINT }}</p>
      </section>
    </template>
    <p v-if="state.isSaving" role="status" class="px-2 text-xs text-subtle">Bezig met bewaren…</p>
    <p v-if="state.problem || photoProblem" role="alert" class="px-2 text-sm text-danger">{{ photoProblem ?? state.problem }}</p>
    <button v-if="!state.isLoaded && !state.isLoading" type="button" class="min-h-11 rounded-pill bg-tint px-4 text-sm font-semibold text-brand focus-visible:outline-2 focus-visible:outline-brand" @click="account.load()">{{ DEVICES_RETRY }}</button>
    <button type="button" :disabled="isSigningOut || state.isSaving" class="mt-2 flex min-h-14.5 w-full items-center justify-center rounded-pill bg-tint font-heading text-base font-semibold text-brand hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60" @click="confirmRef?.open()">{{ SETTINGS_SIGN_OUT }}</button>
    <p v-if="signOutError" role="alert" class="px-2 text-sm text-danger">{{ signOutError }}</p>
    <VaultImageFramer :image="pickedPhoto" shape="circle" @use="savePhoto" @close="pickedPhoto = null" @unreadable="unreadablePhoto" />
    <LayoutConfirmSheet ref="confirm" :title="SETTINGS_SIGN_OUT_QUESTION" :confirm-label="SETTINGS_SIGN_OUT" @confirm="confirmSignOut" />
    <LayoutConfirmSheet ref="remove" :title="PERSONAL_PHOTO_REMOVE_QUESTION" :confirm-label="PERSONAL_PHOTO_REMOVE" @confirm="account.removeAvatar()" />
  </SettingsPage>
</template>
