<script setup lang="ts">
import type { SignedInDevice } from '~/utils/devices';

// "Ingelogde apparaten" (iOS SignedInDevicesScreen): where the account is signed in. This device first, then the
// others, each with a button to sign it out, and one button to sign out everywhere else. Before the database is ready
// for the list, signing out everywhere else already works.
useHead({ title: `${DEVICES_TITLE} - PAVE` });

const devices = useSignedInDevices();
const state = computed(() => devices.state.value);
const asked = ref<SignedInDevice | 'allOthers' | null>(null);
const confirmRef = useTemplateRef<{ open: () => void }>('confirm');
const thisHeadingId = useId();
const othersHeadingId = useId();

const question = computed(() =>
  asked.value === 'allOthers' || !asked.value ? DEVICES_SIGN_OUT_ALL_QUESTION : DEVICES_SIGN_OUT_QUESTION(deviceName(asked.value)),
);

function ask(target: SignedInDevice | 'allOthers') {
  asked.value = target;
  confirmRef.value?.open();
}

async function confirm() {
  const target = asked.value;
  if (target === 'allOthers') await devices.signOutOthers();
  else if (target) await devices.signOut(target);
}

onMounted(() => devices.load());

const signOutAll =
  'flex min-h-14.5 w-full items-center justify-center rounded-pill bg-tint font-heading text-base font-semibold text-brand hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60';
</script>

<template>
  <div class="min-h-0 flex-1 overflow-y-auto bg-surface">
    <SettingsPageHeader :title="DEVICES_TITLE" :back-to="SETTINGS_PATH" :back-label="PERSONAL_BACK" />

    <div class="mx-auto flex w-full max-w-140 flex-col gap-3 px-5.75 pb-12 pt-6">
      <p class="px-2 text-sm text-subtle">{{ DEVICES_INTRO }}</p>

      <div v-if="state.status === 'idle' || state.status === 'loading'" class="flex animate-pulse flex-col gap-3 motion-reduce:animate-none" role="status">
        <span class="sr-only">{{ DEVICES_LOADING }}</span>
        <span v-for="index in 3" :key="index" class="h-19 rounded-pill bg-tile" aria-hidden="true" />
      </div>

      <div v-else-if="state.status === 'failed'" class="flex flex-col items-center gap-4 rounded-pill bg-white px-4 py-8 text-center">
        <p class="text-base font-semibold text-heading">{{ DEVICES_LOAD_FAILED_TITLE }}</p>
        <p class="text-sm text-subtle">{{ state.loadError }}</p>
        <button
          type="button"
          class="min-h-10 rounded-field border border-brand px-4 text-base font-medium text-brand hover:bg-tint focus-visible:outline-2 focus-visible:outline-brand"
          @click="devices.load()"
        >
          {{ DEVICES_RETRY }}
        </button>
      </div>

      <template v-else-if="state.status === 'notSetUp'">
        <div class="flex flex-col gap-1 rounded-pill bg-white p-4">
          <p class="text-base font-semibold text-heading">{{ DEVICES_NOT_SET_UP_TITLE }}</p>
          <p class="text-sm text-subtle">{{ DEVICES_NOT_SET_UP_MESSAGE }}</p>
        </div>
        <button type="button" :class="signOutAll" :disabled="state.signingOut !== null" @click="ask('allOthers')">
          {{ DEVICES_SIGN_OUT_ALL }}
        </button>
      </template>

      <template v-else>
        <section v-if="devices.current.value" :aria-labelledby="thisHeadingId" class="mt-2 flex flex-col gap-3">
          <SettingsSectionTitle :id="thisHeadingId" :title="DEVICES_THIS_DEVICE" />
          <SettingsDeviceRow :device="devices.current.value" />
        </section>

        <section :aria-labelledby="othersHeadingId" class="mt-5 flex flex-col gap-3">
          <SettingsSectionTitle :id="othersHeadingId" :title="DEVICES_OTHER_DEVICES" />
          <p v-if="!devices.others.value.length" class="rounded-pill bg-white p-4 text-sm text-subtle">{{ DEVICES_NO_OTHERS }}</p>
          <template v-else>
            <SettingsDeviceRow
              v-for="device in devices.others.value"
              :key="device.id"
              :device="device"
              can-sign-out
              :is-signing-out="state.signingOut === device.id"
              @sign-out="ask(device)"
            />
            <button type="button" :class="signOutAll" :disabled="state.signingOut !== null" @click="ask('allOthers')">
              {{ DEVICES_SIGN_OUT_ALL }}
            </button>
          </template>
        </section>
      </template>

      <p v-if="state.problem" role="alert" class="px-2 text-xs/normal text-danger">{{ state.problem }}</p>
    </div>

    <LayoutConfirmSheet
      ref="confirm"
      :title="question"
      :message="DEVICES_SIGN_OUT_MESSAGE"
      :confirm-label="SETTINGS_SIGN_OUT"
      @confirm="confirm"
    />
  </div>
</template>
