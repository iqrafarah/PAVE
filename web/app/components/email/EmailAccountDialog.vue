<script setup lang="ts">
// Meldingen › E-mail (iOS EmailAccountsScreen): the connected iCloud Mail account and disconnecting it, or connecting
// one with the address and an app-specific password, which Apple requires for every app other than its own.
const isOpen = defineModel<boolean>('open', { required: true });

const email = useEmail();
const address = ref('');
const password = ref('');
const isBusy = ref(false);
const problem = ref<string | null>(null);
const ids = { address: useId(), password: useId(), help: useId(), problem: useId() };
const disconnectRef = useTemplateRef<{ open: () => void }>('disconnect');

const account = computed(() => email.state.value.account);
const domainProblem = computed(() => {
  const kind = addressProblem(address.value);
  if (kind === 'outlook') return EMAIL_NOT_ICLOUD_OUTLOOK;
  return kind === 'other' ? EMAIL_NOT_ICLOUD : null;
});
const canConnect = computed(() => /^[^@\s]+@[^@\s]+$/.test(address.value.trim()) && password.value.trim() && !domainProblem.value && !isBusy.value);

watch(isOpen, (open) => {
  if (!open) return;
  address.value = '';
  password.value = '';
  problem.value = null;
});

async function connect() {
  if (!canConnect.value) return;
  isBusy.value = true;
  problem.value = null;
  const { error } = await email.connect(address.value, password.value);
  isBusy.value = false;
  if (error) {
    problem.value = error;
    return;
  }
  password.value = '';
  isOpen.value = false;
}

async function disconnect() {
  isBusy.value = true;
  const { error } = await email.disconnect();
  isBusy.value = false;
  problem.value = error;
}

const field =
  'h-11 w-full rounded-field border border-field-line bg-white px-3 text-sm font-medium text-heading outline-none focus:border-brand aria-invalid:border-danger';
const label = 'text-sm font-semibold text-heading';
const primaryButton =
  'min-h-11 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60';
const dangerButton =
  'min-h-11 w-full rounded-field bg-field-line px-4 text-base font-medium text-danger hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60';
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="account ? EMAIL_ACCOUNT_TITLE : EMAIL_CONNECT_TITLE" width="narrow">
    <div class="flex flex-col gap-5 pb-2">
      <template v-if="account">
        <section class="flex flex-col gap-2">
          <p class="text-[0.6875rem] font-semibold uppercase tracking-wide text-subtle">{{ EMAIL_THIS_ACCOUNT }}</p>
          <div class="flex items-center gap-3 rounded-xl border border-card-border bg-white p-3.5">
            <NotificationKindIcon kind="email" />
            <span class="flex min-w-0 flex-1 flex-col">
              <span class="text-sm font-semibold text-heading">{{ EMAIL_PROVIDER }}</span>
              <span class="truncate text-xs text-subtle">{{ account.address }}</span>
            </span>
            <span class="rounded-full bg-tint px-2 py-0.5 text-xs font-medium text-brand">{{ EMAIL_CONNECTED }}</span>
          </div>
        </section>
        <section class="flex flex-col gap-1">
          <h3 class="text-sm font-semibold text-heading">{{ EMAIL_WHICH_TITLE }}</h3>
          <p class="text-sm text-subtle">{{ EMAIL_WHICH_MESSAGE }}</p>
        </section>
        <p class="text-xs text-subtle">{{ EMAIL_PRIVACY }}</p>
      </template>

      <form v-else id="email-connect" class="flex flex-col gap-4" @submit.prevent="connect">
        <p class="text-sm text-subtle">{{ EMAIL_CONNECT_INTRO }}</p>
        <div class="flex items-center gap-3 rounded-xl border border-brand bg-tint p-3.5">
          <NotificationKindIcon kind="email" />
          <span class="flex min-w-0 flex-col">
            <span class="text-sm font-semibold text-heading">{{ EMAIL_PROVIDER }}</span>
            <span class="text-xs text-subtle">{{ EMAIL_PROVIDER_SUBTITLE }}</span>
          </span>
        </div>

        <div class="flex flex-col gap-1.5">
          <label :for="ids.address" :class="label">{{ EMAIL_ADDRESS }}</label>
          <input
            :id="ids.address"
            v-model="address"
            type="email"
            autocomplete="email"
            inputmode="email"
            placeholder="naam@icloud.com"
            :aria-invalid="Boolean(domainProblem)"
            :aria-describedby="domainProblem ? ids.problem : undefined"
            :class="field"
          />
          <p v-if="domainProblem" :id="ids.problem" class="text-xs text-danger">{{ domainProblem }}</p>
        </div>

        <div class="flex flex-col gap-1.5">
          <label :for="ids.password" :class="label">{{ EMAIL_PASSWORD }}</label>
          <input
            :id="ids.password"
            v-model="password"
            type="password"
            autocomplete="off"
            placeholder="xxxx-xxxx-xxxx-xxxx"
            :aria-describedby="ids.help"
            :class="field"
          />
          <p :id="ids.help" class="text-xs text-subtle">
            {{ EMAIL_PASSWORD_HELP }}
            <a href="https://account.apple.com" target="_blank" rel="noopener noreferrer" class="font-semibold text-brand hover:underline">
              {{ EMAIL_APPLE_LINK }}
            </a>
          </p>
        </div>

        <section class="flex flex-col gap-1">
          <h3 class="text-sm font-semibold text-heading">{{ EMAIL_WHICH_TITLE }}</h3>
          <p class="text-sm text-subtle">{{ EMAIL_WHICH_MESSAGE }}</p>
        </section>
        <p class="text-xs text-subtle">{{ EMAIL_PRIVACY }}</p>
      </form>

      <p v-if="problem" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ problem }}</p>
    </div>

    <template #footer>
      <button v-if="account" type="button" :class="dangerButton" :disabled="isBusy" @click="disconnectRef?.open()">{{ EMAIL_DISCONNECT }}</button>
      <button v-else type="submit" form="email-connect" :class="primaryButton" :disabled="!canConnect">
        {{ isBusy ? EMAIL_CONNECTING : EMAIL_CONNECT }}
      </button>
    </template>
  </VaultSheet>

  <LayoutConfirmSheet
    ref="disconnect"
    :title="EMAIL_DISCONNECT_TITLE"
    :message="EMAIL_DISCONNECT_MESSAGE"
    :confirm-label="EMAIL_DISCONNECT"
    @confirm="disconnect"
  />
</template>
