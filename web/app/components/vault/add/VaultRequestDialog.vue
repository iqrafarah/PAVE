<script setup lang="ts">
import type { VaultItem } from '~/types/vault';
import type { ValidationContact, ValidationFilters, ValidationOrganizationKind, ValidationPlace } from '~/types/verification';

// "Bevestiging aanvragen", as iOS VaultRequestConfirmationSheet: the evidence and what comes with it on top, then the
// organisation with one of its locations ("McDonald's · Westermarkt, Tilburg": from an earlier request or the evidence
// by ID, a "Bedoel je …?" from the typed name, or found with the search and its kinds), then one person there from
// those who may confirm this kind of evidence, with their photo, and the button with the name.
// Closing with something chosen asks first. vault-review checks the choice again (docs/verificatie.md).
const props = defineProps<{
  itemId: string | null;
}>();

const emit = defineEmits<{
  close: [];
}>();

const KINDS: ValidationOrganizationKind[] = ['school', 'company', 'government', 'other'];

const vault = useVault();
const form = useValidationForm();
const { sendRequest } = useVerification();
const discardRef = useTemplateRef<{ open: () => void }>('discard');
const ids = { contactSearch: useId(), organizationSearch: useId(), organization: useId(), contact: useId() };
const showsMissing = ref(false);
const isSending = ref(false);
const isSent = ref(false);
const sendError = ref<string | null>(null);
const choosesOrganization = ref(false);

const item = computed<VaultItem | null>(() => vault.state.value.items.find((entry) => entry.id === props.itemId) ?? null);
const hasChanges = computed(() => !isSent.value && form.isDirty.value);
const isOpen = computed({
  get: () => item.value !== null,
  set: (open) => {
    if (open) return;
    // ✕ or Escape in the organisation search goes back to the form.
    if (choosesOrganization.value) choosesOrganization.value = false;
    else if (hasChanges.value) discardRef.value?.open();
    else emit('close');
  },
});
const period = computed(() => (item.value ? itemPeriod(item.value) : null));
const shared = computed(() => (item.value ? sharedLine(item.value) : null));
const errorMessage = computed(() => sendError.value ?? form.directoryError.value);
const sendTitle = computed(() => {
  if (isSending.value) return REQUEST_SENDING;
  return form.contact.value ? REQUEST_SEND_TO(form.contact.value.name) : REQUEST_SEND;
});
const showsContactSection = computed(() => Boolean(form.place.value) || form.previousPeople.value.length > 0);
const searchTitle = computed(() => {
  if (form.suggestion.value) return REQUEST_ORGANISATION_SEARCH_OTHER;
  if (form.suggestedSearch.value) return REQUEST_ORGANISATION_SEARCH_PLACE(form.suggestedSearch.value);
  return REQUEST_ORGANISATION_SEARCH;
});

/** Only filters that narrow something at this location. The location itself is chosen, not filtered. */
const filterFields = computed(() => {
  const fields: { key: keyof ValidationFilters; label: string; all: string; options: { value: string; label: string }[] }[] = [
    { key: 'department', label: REQUEST_FILTER_DEPARTMENT, all: REQUEST_FILTER_DEPARTMENT_ALL, options: form.departmentOptions.value },
    { key: 'function', label: REQUEST_FILTER_FUNCTION, all: REQUEST_FILTER_FUNCTION_ALL, options: form.functionOptions.value },
  ];
  return fields.filter((field) => field.options.length > 1);
});

const sectionCard = 'flex flex-col gap-3 rounded-2xl border border-card-border bg-white p-4.5';
const sectionTitle = 'text-sm font-semibold text-heading';
const subheading = 'pt-0.5 text-[0.6875rem] font-semibold uppercase tracking-wide text-subtle';
const linkButton = 'rounded-md px-1 text-sm font-semibold text-brand hover:underline focus-visible:outline-2 focus-visible:outline-brand';
const primaryButton =
  'min-h-11 w-full rounded-field bg-brand px-4 text-base font-medium text-white hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand disabled:opacity-60';
const secondaryButton =
  'min-h-11 w-full rounded-field bg-field-line px-4 text-base font-medium text-heading hover:bg-tile focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

function problem(field: ValidationField) {
  return showsMissing.value && form.missingFields.value.includes(field) ? REQUEST_MISSING[field] : null;
}

function openOrganizationSearch() {
  choosesOrganization.value = true;
  form.openPlaceSearch();
  nextTick(() => document.getElementById(ids.organizationSearch)?.focus());
}

function chooseOrganization(place: ValidationPlace) {
  form.pickPlace(place);
  choosesOrganization.value = false;
}

function isChosen(person: ValidationContact) {
  return form.contact.value?.id === person.id;
}

async function send() {
  showsMissing.value = true;
  if (!item.value) return;
  const choice = form.toChoice(item.value.id);
  if (!choice) return;
  isSending.value = true;
  sendError.value = null;
  const { error } = await sendRequest(choice);
  isSending.value = false;
  if (error) sendError.value = error;
  else isSent.value = true;
}

function seeInNotifications() {
  emit('close');
  navigateTo('/meldingen');
}

watch(
  () => item.value?.id,
  (id, previousId) => {
    if (!id || id === previousId || !item.value) return;
    showsMissing.value = false;
    isSent.value = false;
    sendError.value = null;
    choosesOrganization.value = false;
    form.start(item.value);
  },
  { immediate: true },
);
</script>

<template>
  <VaultSheet v-model:open="isOpen" :title="choosesOrganization ? REQUEST_ORGANISATION_PICKER : REQUEST_TITLE" width="narrow">
    <!-- Sent: the green seal, who decides and what happens next. -->
    <div v-if="isSent" class="flex flex-col items-center gap-4 py-10 text-center" role="status">
      <span class="flex size-18 items-center justify-center rounded-full bg-tint text-brand" aria-hidden="true">
        <VaultIcon src="/images/vault/status-verified.svg" class="size-8" />
      </span>
      <h3 class="font-heading text-xl font-semibold text-heading">{{ REQUEST_SENT_TITLE }}</h3>
      <p class="max-w-95 text-sm font-medium text-subtle">{{ REQUEST_SENT_MESSAGE(form.contact.value?.name ?? null) }}</p>
    </div>

    <!-- The organisation search (iOS VaultOrganizationSearchSheet): a name, Alles or one kind, a page at a time. -->
    <div v-else-if="choosesOrganization" class="flex flex-col gap-3">
      <label :for="ids.organizationSearch" class="flex h-11 items-center gap-2 rounded-field border border-field-line bg-white px-3 has-focus-visible:border-brand">
        <LayoutPaveIcon name="search" class="size-4 shrink-0 text-subtle" />
        <span class="sr-only">{{ REQUEST_ORGANISATION_PROMPT }}</span>
        <input
          :id="ids.organizationSearch"
          :value="form.placeQuery.value"
          type="search"
          :placeholder="REQUEST_ORGANISATION_PROMPT"
          class="min-w-0 flex-1 bg-transparent text-sm font-medium text-heading outline-none placeholder:text-subtle"
          @input="form.searchPlaces(($event.target as HTMLInputElement).value)"
        />
      </label>
      <div class="flex flex-wrap gap-2" role="group" :aria-label="REQUEST_ORGANISATION">
        <button
          v-for="option in [null, ...KINDS]"
          :key="option ?? 'all'"
          type="button"
          :aria-pressed="form.placeKind.value === option"
          :class="form.placeKind.value === option ? 'border-brand bg-brand text-white' : 'border-card-border bg-white text-heading hover:bg-surface'"
          class="h-8 rounded-full border px-3.5 text-xs font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
          @click="form.setPlaceKind(option)"
        >
          {{ option ? REQUEST_KIND_FILTERS[option] : REQUEST_KIND_ALL }}
        </button>
      </div>

      <p v-if="form.isLoadingPlaces.value && !form.places.value.length" role="status" class="py-6 text-center text-sm text-subtle">
        {{ REQUEST_LOADING }}
      </p>
      <LayoutEmptyState
        v-else-if="form.placesFailed.value"
        icon="search"
        :title="REQUEST_ORGANISATION_FAILED_TITLE"
        :message="REQUEST_ORGANISATION_FAILED_MESSAGE"
        class="py-6"
      />
      <LayoutEmptyState
        v-else-if="!form.places.value.length"
        icon="search"
        :title="REQUEST_ORGANISATION_NONE_TITLE"
        :message="REQUEST_ORGANISATION_NONE_MESSAGE"
        class="py-6"
      />
      <ul v-else class="flex flex-col divide-y divide-card-line rounded-2xl border border-card-border bg-white" :aria-busy="form.isLoadingPlaces.value">
        <li v-for="entry in form.places.value" :key="entry.locationId">
          <button
            type="button"
            :aria-pressed="form.place.value?.locationId === entry.locationId"
            :aria-label="[placeTitle(entry), entry.address].filter(Boolean).join(', ')"
            class="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-surface focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-brand"
            @click="chooseOrganization(entry)"
          >
            <VaultLogo :name="entry.organizationName" :logo-url="entry.logoUrl" :size="34" />
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="text-sm font-medium text-heading">{{ entry.organizationName }}</span>
              <span class="text-xs text-subtle">{{ placeDetails(entry, !form.placeKind.value) }}</span>
              <span v-if="entry.address" class="truncate text-xs text-subtle">{{ entry.address }}</span>
            </span>
            <LayoutIcon v-if="form.place.value?.locationId === entry.locationId" name="check" class="size-4 shrink-0 text-brand" />
          </button>
        </li>
      </ul>
      <button
        v-if="form.places.value.length < form.placeTotal.value"
        type="button"
        :disabled="form.isLoadingMorePlaces.value"
        :class="linkButton"
        class="h-10 self-center"
        @click="form.loadMorePlaces()"
      >
        {{ form.isLoadingMorePlaces.value ? REQUEST_LOADING : REQUEST_LOAD_MORE(form.places.value.length, form.placeTotal.value) }}
      </button>
    </div>

    <form v-else-if="item" class="flex flex-col gap-5" novalidate @submit.prevent="send">
      <p v-if="errorMessage" role="alert" class="rounded-xl bg-status-rejected-surface p-3 text-sm text-status-rejected">{{ errorMessage }}</p>

      <!-- What is shared: the evidence, and below it what comes with it. -->
      <div class="flex items-center gap-3 rounded-2xl border border-card-border bg-white p-3.5">
        <VaultLogo :name="item.organisationName ?? item.title" :logo-url="item.logoUrl" :size="52" />
        <div class="flex min-w-0 flex-col gap-1">
          <p translate="no" class="line-clamp-2 text-sm font-semibold text-heading">{{ item.title }}</p>
          <p v-if="period" class="flex items-center gap-1.5 text-xs font-medium text-heading">
            <VaultIcon src="/images/vault/calendar.svg" class="size-4 shrink-0 text-subtle" />{{ period }}
          </p>
          <p v-if="shared" class="text-xs text-subtle">{{ shared }}</p>
        </div>
      </div>

      <section :aria-labelledby="ids.organization" :class="sectionCard">
        <h3 :id="ids.organization" :class="sectionTitle">{{ REQUEST_ORGANISATION }}</h3>
        <div v-if="form.place.value" class="flex items-center gap-3">
          <VaultLogo :name="form.place.value.organizationName" :logo-url="form.place.value.logoUrl" :size="40" />
          <span class="flex min-w-0 flex-1 flex-col gap-0.5">
            <span class="line-clamp-2 text-sm font-semibold text-heading">{{ form.place.value.organizationName }}</span>
            <span class="line-clamp-2 text-xs text-subtle">{{ placeDetails(form.place.value) }}</span>
            <span v-if="form.place.value.address" class="truncate text-xs text-subtle">{{ form.place.value.address }}</span>
          </span>
          <button type="button" :class="linkButton" :aria-label="REQUEST_ORGANISATION_CHANGE_LABEL" @click="openOrganizationSearch">
            {{ REQUEST_ORGANISATION_CHANGE }}
          </button>
        </div>
        <p v-else-if="form.isStarting.value" role="status" class="py-1.5 text-sm text-subtle">{{ REQUEST_LOADING }}</p>
        <template v-else>
          <div v-if="form.suggestion.value" class="flex items-center gap-3">
            <VaultLogo :name="form.suggestion.value.organizationName" :logo-url="form.suggestion.value.logoUrl" :size="40" />
            <span class="flex min-w-0 flex-1 flex-col gap-0.5">
              <span class="line-clamp-2 text-sm font-semibold text-heading">{{ REQUEST_SUGGESTION(form.suggestion.value.organizationName) }}</span>
              <span class="line-clamp-2 text-xs text-subtle">{{ placeDetails(form.suggestion.value) }}</span>
              <span v-if="form.suggestion.value.address" class="truncate text-xs text-subtle">{{ form.suggestion.value.address }}</span>
            </span>
            <button
              type="button"
              :class="linkButton"
              :aria-label="REQUEST_SUGGESTION_CHOOSE_LABEL(placeTitle(form.suggestion.value))"
              @click="form.pickPlace(form.suggestion.value)"
            >
              {{ REQUEST_SUGGESTION_CHOOSE }}
            </button>
          </div>
          <button
            type="button"
            :aria-invalid="Boolean(problem('organization')) || undefined"
            class="flex h-12 items-center gap-2.5 rounded-xl border border-card-border bg-white px-3.5 text-left text-sm font-medium text-subtle hover:bg-surface focus-visible:outline-2 focus-visible:outline-brand aria-invalid:border-danger"
            @click="openOrganizationSearch"
          >
            <LayoutPaveIcon name="search" class="size-4 shrink-0" />
            <span class="truncate">{{ searchTitle }}</span>
          </button>
        </template>
        <p v-if="problem('organization')" class="text-xs text-danger">{{ problem('organization') }}</p>
      </section>

      <section v-if="showsContactSection" :aria-labelledby="ids.contact" :class="sectionCard">
        <h3 :id="ids.contact" :class="sectionTitle">{{ REQUEST_CONTACT }}</h3>

        <!-- No organisation yet: whom you asked before, with their organisation. -->
        <div v-if="!form.place.value" role="radiogroup" :aria-labelledby="ids.contact" class="flex flex-col gap-2">
          <p :class="subheading">{{ REQUEST_PREVIOUS }}</p>
          <VaultRequestPerson
            v-for="person in form.previousPeople.value"
            :key="person.id"
            :person="person"
            :details="contactDetails(person, true)"
            :is-chosen="isChosen(person)"
            :photo-url="form.photos.value[person.id]"
            @choose="form.choosePerson(person)"
          />
        </div>

        <p v-else-if="form.place.value.availableContacts === 0" class="text-xs text-subtle">{{ REQUEST_NOBODY_CAN_CONFIRM }}</p>

        <template v-else>
          <label :for="ids.contactSearch" class="flex h-11 items-center gap-2 rounded-field border border-field-line bg-white px-3 has-focus-visible:border-brand">
            <LayoutPaveIcon name="search" class="size-4 shrink-0 text-subtle" />
            <span class="sr-only">{{ REQUEST_CONTACT_SEARCH }}</span>
            <input
              :id="ids.contactSearch"
              :value="form.search.value"
              type="search"
              :placeholder="REQUEST_CONTACT_SEARCH"
              class="min-w-0 flex-1 bg-transparent text-sm font-medium text-heading outline-none placeholder:text-subtle"
              @input="form.setSearch(($event.target as HTMLInputElement).value)"
            />
          </label>

          <div v-if="filterFields.length" class="flex flex-wrap gap-2">
            <label
              v-for="field in filterFields"
              :key="field.key"
              :class="form.filters.value[field.key] ? 'border-brand bg-tint' : 'border-card-border bg-white'"
              class="relative flex h-8 items-center rounded-full border pl-3 pr-2 text-xs font-medium text-heading has-focus-visible:outline-2 has-focus-visible:outline-brand"
            >
              <span class="sr-only">{{ field.label }}</span>
              <select
                :value="form.filters.value[field.key]"
                class="max-w-40 cursor-pointer appearance-none truncate bg-transparent pr-4 outline-none"
                @change="form.setFilter(field.key, ($event.target as HTMLSelectElement).value)"
              >
                <option value="">{{ field.all }}</option>
                <option v-for="option in field.options" :key="option.value" :value="option.value">{{ option.label }}</option>
              </select>
              <LayoutIcon name="chevronDown" class="pointer-events-none absolute right-2 size-3 text-subtle" />
            </label>
          </div>

          <div role="radiogroup" :aria-labelledby="ids.contact" class="flex flex-col gap-2">
            <template v-if="form.previousHere.value.length">
              <p :class="subheading">{{ REQUEST_PREVIOUS }}</p>
              <VaultRequestPerson
                v-for="person in form.previousHere.value"
                :key="person.id"
                :person="person"
                :details="contactDetails(person)"
                :is-chosen="isChosen(person)"
            :photo-url="form.photos.value[person.id]"
                @choose="form.choosePerson(person)"
              />
              <p v-if="form.otherPeople.value.length" :class="subheading">{{ REQUEST_ALL_CONTACTS }}</p>
            </template>

            <p v-if="form.isLoadingPeople.value && !form.people.value.length" role="status" class="py-2.5 text-center text-sm text-subtle">
              {{ REQUEST_LOADING }}
            </p>
            <div v-else-if="!form.people.value.length" class="flex flex-col items-start gap-1.5 py-1">
              <p class="text-sm font-medium text-heading">{{ REQUEST_NO_CONTACTS }}</p>
              <button v-if="form.hasFilters.value" type="button" :class="linkButton" @click="form.clearFilters()">{{ REQUEST_FILTERS_CLEAR }}</button>
            </div>
            <template v-else>
              <div :class="form.isLoadingPeople.value ? 'opacity-50' : ''" class="flex flex-col gap-2" :aria-busy="form.isLoadingPeople.value">
                <VaultRequestPerson
                  v-for="person in form.otherPeople.value"
                  :key="person.id"
                  :person="person"
                  :details="contactDetails(person)"
                  :is-chosen="isChosen(person)"
            :photo-url="form.photos.value[person.id]"
                  @choose="form.choosePerson(person)"
                />
              </div>
              <button
                v-if="form.people.value.length < form.peopleTotal.value"
                type="button"
                :disabled="form.isLoadingMorePeople.value"
                :class="linkButton"
                class="h-10 self-center"
                @click="form.loadMorePeople()"
              >
                {{ form.isLoadingMorePeople.value ? REQUEST_LOADING : REQUEST_LOAD_MORE(form.people.value.length, form.peopleTotal.value) }}
              </button>
            </template>
          </div>
        </template>
        <p v-if="problem('contact')" class="text-xs text-danger">{{ problem('contact') }}</p>
      </section>
    </form>

    <template #footer>
      <div v-if="isSent" class="flex w-full flex-col gap-2.5">
        <button type="button" :class="primaryButton" @click="seeInNotifications">{{ REQUEST_SEE_IN_NOTIFICATIONS }}</button>
        <button type="button" :class="secondaryButton" @click="emit('close')">{{ REQUEST_CLOSE }}</button>
      </div>
      <button v-else-if="choosesOrganization" type="button" :class="secondaryButton" @click="choosesOrganization = false">
        {{ REQUEST_ORGANISATION_DONE }}
      </button>
      <div v-else-if="item" class="flex w-full flex-col items-center gap-2.5">
        <button type="button" :disabled="isSending || form.isStarting.value" :class="primaryButton" @click="send">{{ sendTitle }}</button>
        <p v-if="form.contact.value" class="max-w-80 text-center text-xs text-subtle">{{ REQUEST_ONLY_THEY_SEE(form.contact.value.name) }}</p>
      </div>
    </template>
  </VaultSheet>

  <LayoutConfirmSheet
    ref="discard"
    :title="REQUEST_DISCARD_TITLE"
    :confirm-label="REQUEST_DISCARD"
    :cancel-label="REQUEST_DISCARD_KEEP"
    @confirm="emit('close')"
  />
</template>
