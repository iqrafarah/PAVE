<script setup lang="ts">
import type { SignedInDevice } from '~/utils/devices';

// One signed-in device (iOS SignedInDeviceRow): an icon for the kind of device, its name, when it was active and, for
// another device, a button to sign it out.
const props = defineProps<{
  device: SignedInDevice;
  isSigningOut?: boolean;
  canSignOut?: boolean;
}>();

const emit = defineEmits<{
  signOut: [];
}>();

const name = computed(() => deviceName(props.device));
</script>

<template>
  <div class="flex items-center gap-3 rounded-pill bg-white p-3">
    <span
      :class="device.isCurrent ? 'bg-brand text-white' : 'bg-drop text-brand'"
      class="flex size-10 shrink-0 items-center justify-center rounded-[0.625rem]"
      aria-hidden="true"
    >
      <VaultIcon :src="deviceIcon(device)" class="size-5" />
    </span>
    <span class="flex min-w-0 flex-1 flex-col gap-0.75">
      <span class="text-base font-semibold text-heading">{{ name }}</span>
      <span :class="device.isCurrent ? 'text-brand' : 'text-subtle'" class="text-xs/normal">{{ deviceActivity(device) }}</span>
      <span class="text-xs/normal text-subtle">{{ deviceSignedIn(device) }}</span>
    </span>
    <button
      v-if="canSignOut"
      type="button"
      :disabled="isSigningOut"
      :aria-label="DEVICES_SIGN_OUT_ON(name)"
      :aria-busy="isSigningOut"
      class="min-h-8.5 min-w-11 shrink-0 rounded-full bg-critical/8 px-3 text-xs font-semibold text-critical hover:bg-critical/15 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60"
      @click="emit('signOut')"
    >
      {{ isSigningOut ? '…' : SETTINGS_SIGN_OUT }}
    </button>
  </div>
</template>
