<script setup lang="ts">
// The iPhone settings screen (ios/PAVE/Features/Settings/SettingsScreen.swift), with only what exists on the web:
// Account and Ayla. Same words and order as on the iPhone. The lock timer and iPhone search are iPhone-only.
useHead({ title: `${SETTINGS_TITLE} - PAVE` });

const account = useAccount();
const { signOut } = useAuth();
const memory = useAylaMemory();
const voiceText = useAylaVoiceText();

const showsVoiceText = computed({
  get: () => voiceText.showsVoiceText.value,
  set: (isOn: boolean) => voiceText.set(isOn),
});

const fullName = computed(() => account.state.value.fullName);
const signOutError = ref<string | null>(null);
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');

const accountHeadingId = useId();
const aylaHeadingId = useId();

const memorySummary = computed(() =>
  getMemorySummary(memory.state.value.status, memory.state.value.isEnabled, memory.state.value.notes.length),
);

async function confirmSignOut() {
  signOutError.value = null;
  const { error } = await signOut();
  if (error) signOutError.value = SETTINGS_SIGN_OUT_FAILED;
}

onMounted(async () => {
  voiceText.load();
  if (memory.state.value.status === 'idle') memory.load();
  await account.load();
});
</script>

<template>
  <div class="min-h-0 flex-1 overflow-y-auto bg-surface">
    <header class="flex items-center gap-2 px-4 pt-7.5 sm:px-13.25">
      <LayoutMenuLogo />
      <AylaSlashIcon class="h-7.5 w-4.5" />
      <h1 class="text-3xl font-semibold text-brand">{{ SETTINGS_TITLE }}</h1>
    </header>

    <!-- iOS: 23 on the sides, 32 from the top, 12 between items, 20 more above a header, at most 560 wide. -->
    <div class="mx-auto flex w-full max-w-140 flex-col gap-3 px-5.75 pb-12 pt-8">
      <section :aria-labelledby="accountHeadingId" class="flex flex-col gap-3">
        <SettingsSectionTitle :id="accountHeadingId" :title="SETTINGS_ACCOUNT" />
        <div class="flex items-center gap-3 rounded-pill bg-white p-3">
          <SettingsAccountBadge :name="fullName" :avatar-url="account.state.value.avatarUrl" />
          <span class="truncate text-base font-semibold text-heading">{{ fullName ?? SETTINGS_YOUR_ACCOUNT }}</span>
        </div>
        <button
          type="button"
          class="flex min-h-14.5 w-full items-center justify-center rounded-pill bg-tint font-heading text-base font-semibold text-brand hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="confirmRef?.open()"
        >
          {{ SETTINGS_SIGN_OUT }}
        </button>
        <p v-if="signOutError" role="alert" class="px-2 text-xs/normal text-danger">{{ signOutError }}</p>
      </section>

      <section :aria-labelledby="aylaHeadingId" class="mt-5 flex flex-col gap-3">
        <SettingsSectionTitle :id="aylaHeadingId" :title="SETTINGS_AYLA" />
        <NuxtLink
          :to="MEMORY_PAGE_PATH"
          class="flex items-center gap-3 rounded-pill bg-white p-3 hover:bg-tint focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
          <span class="flex min-w-0 flex-1 flex-col gap-1">
            <span class="text-base font-semibold text-heading">{{ SETTINGS_MEMORY_LINK }}</span>
            <span class="text-xs/normal text-subtle">{{ memorySummary }}</span>
          </span>
          <LayoutPaveIcon name="chevronRight" class="h-4 w-2.25 text-subtle" />
        </NuxtLink>
        <SettingsSwitchCard
          v-model="showsVoiceText"
          :title="SETTINGS_VOICE_TEXT"
          :explanation="SETTINGS_VOICE_TEXT_EXPLANATION"
        />
      </section>
    </div>

    <LayoutConfirmSheet
      ref="confirm"
      :title="SETTINGS_SIGN_OUT_QUESTION"
      :confirm-label="SETTINGS_SIGN_OUT"
      @confirm="confirmSignOut"
    />
  </div>
</template>
