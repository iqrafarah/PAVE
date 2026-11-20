<script setup lang="ts">
// "Accountpincode" in Privacy: the one PIN of the account for locked chats. It belongs to the account, not to a device,
// so someone who set it on their phone can change it here, or reset it when they forgot it.
// Change: current PIN, then the new one twice. Reset: asks first, because the locked chats are deleted.
const lock = useAylaChatLock();

type Step = 'current' | 'new' | 'recover' | null;
const step = ref<Step>(null);
const currentPin = ref('');
const pinError = ref<string | null>(null);
const isBusy = ref(false);
const result = ref<{ text: string; isError: boolean } | null>(null);
const headingId = useId();
const deleteRef = useTemplateRef<{ open: () => void }>('deleteAll');

const hasPin = computed(() => lock.state.value.status === 'ready' && lock.state.value.hasPin);

function startChange() {
  result.value = null;
  pinError.value = null;
  step.value = 'current';
}

function close() {
  step.value = null;
  currentPin.value = '';
  pinError.value = null;
}

// The database checks the current PIN again when the new one is saved; this first check only avoids typing a new
// PIN for nothing.
async function checkCurrent(pin: string) {
  isBusy.value = true;
  pinError.value = null;
  const check = await lock.checkPin(pin);
  isBusy.value = false;
  if (check === 'right') {
    currentPin.value = pin;
    step.value = 'new';
  } else {
    pinError.value = { wrong: AYLA_PIN_WRONG, blocked: AYLA_PIN_BLOCKED, failed: AYLA_PINCODE_FAILED }[check];
  }
}

async function saveNew(newPin: string) {
  isBusy.value = true;
  const check = await lock.changePin(currentPin.value, newPin);
  isBusy.value = false;
  close();
  result.value =
    check === 'right' ? { text: ACCOUNT_PIN_CHANGED, isError: false } : { text: AYLA_PINCODE_FAILED, isError: true };
}

function startRecover() {
  result.value = null;
  step.value = 'recover';
}

function recovered() {
  close();
  result.value = { text: ACCOUNT_PIN_WAS_RESET, isError: false };
}

function recoverFailed() {
  close();
  result.value = { text: AYLA_PINCODE_FAILED, isError: true };
}

async function deleteAll() {
  close();
  const { isFailed } = await lock.resetPin();
  result.value = isFailed ? { text: AYLA_PINCODE_FAILED, isError: true } : { text: ACCOUNT_PIN_DELETED, isError: false };
}

onMounted(() => {
  if (lock.state.value.status === 'idle') lock.load();
});

const rowButton =
  'min-h-10 shrink-0 rounded-pill px-5 text-base font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
</script>

<template>
  <section class="flex flex-col gap-3" :aria-labelledby="headingId">
    <div class="flex flex-col gap-1 px-2">
      <h2 :id="headingId" class="text-base font-semibold text-heading">{{ ACCOUNT_PIN_TITLE }}</h2>
      <p class="text-sm text-subtle">{{ ACCOUNT_PIN_INTRO }}</p>
    </div>

    <p v-if="lock.state.value.status === 'ready' && !hasPin" class="rounded-pill bg-white p-4 text-sm text-subtle">
      {{ ACCOUNT_PIN_NONE }}
    </p>

    <SettingsGroup v-else-if="hasPin">
      <div class="flex items-center gap-4 p-4">
        <div class="min-w-0 flex-1">
          <p class="text-base font-semibold text-heading">{{ ACCOUNT_PIN_CHANGE_TITLE }}</p>
          <p class="text-sm text-subtle">{{ ACCOUNT_PIN_CHANGE_BODY }}</p>
        </div>
        <button type="button" :class="rowButton" class="bg-tint text-heading hover:bg-brand-soft" @click="startChange">
          {{ ACCOUNT_PIN_CHANGE_BUTTON }}
        </button>
      </div>
      <div class="flex items-center gap-4 p-4">
        <div class="min-w-0 flex-1">
          <p class="text-base font-semibold text-heading">{{ ACCOUNT_PIN_RESET_TITLE }}</p>
          <p class="text-sm text-subtle">{{ ACCOUNT_PIN_RESET_BODY }}</p>
        </div>
        <button type="button" :class="rowButton" class="bg-danger/10 text-danger hover:bg-danger/20" @click="startRecover">
          {{ ACCOUNT_PIN_RESET_BUTTON }}
        </button>
      </div>
    </SettingsGroup>

    <p v-if="result" role="status" :class="result.isError ? 'text-danger' : 'text-subtle'" class="px-2 text-sm">
      {{ result.text }}
    </p>

    <AylaPinDialog
      v-if="step === 'current'"
      mode="enter"
      is-change
      :error="pinError"
      :is-busy="isBusy"
      @complete="checkCurrent"
      @forgot="startRecover"
      @close="close"
    />
    <AylaPinDialog v-else-if="step === 'new'" mode="create" is-change :is-busy="isBusy" @complete="saveNew" @close="close" />
    <AylaPinRecover
      v-else-if="step === 'recover'"
      @done="recovered"
      @failed="recoverFailed"
      @close="close"
      @delete-all="deleteRef?.open()"
    />
    <LayoutConfirmSheet
      ref="deleteAll"
      :title="AYLA_PIN_RESET_QUESTION"
      :message="ACCOUNT_PIN_DELETE_BODY"
      :confirm-label="AYLA_PIN_RESET_CONFIRM"
      @confirm="deleteAll"
    />
  </section>
</template>
