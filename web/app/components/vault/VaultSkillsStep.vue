<script setup lang="ts">
// Step 3 "Vaardigheden" (Figma 1167:11255): pick skills you already have in your vault, take Ayla's suggestions, or
// type your own. The chosen ones are the grey chips at the bottom; click one to take it away again.
const props = defineProps<{
  vaultSkills: string[];
  aylaSkills: string[];
  isLoading: boolean;
}>();

const selected = defineModel<string[]>('selected', { required: true });

const MAX_SKILL_LENGTH = 120;
const query = ref('');
const searchId = useId();
const vaultTitleId = useId();
const aylaTitleId = useId();

const selectedKeys = computed(() => new Set(selected.value.map((name) => name.toLowerCase())));
const isSelected = (name: string) => selectedKeys.value.has(name.toLowerCase());

const typed = computed(() => query.value.trim().slice(0, MAX_SKILL_LENGTH));
const matches = computed(() => {
  const search = typed.value.toLowerCase();
  if (!search) return [];
  const known = [...new Set([...props.vaultSkills, ...props.aylaSkills])];
  return known.filter((name) => name.toLowerCase().includes(search) && !isSelected(name)).slice(0, 5);
});
const canAddTyped = computed(
  () => Boolean(typed.value) && !isSelected(typed.value) && !matches.value.some((name) => name.toLowerCase() === typed.value.toLowerCase()),
);

function add(name: string) {
  if (!isSelected(name)) selected.value = [...selected.value, name];
}

function remove(name: string) {
  selected.value = selected.value.filter((item) => item.toLowerCase() !== name.toLowerCase());
}

function toggle(name: string) {
  if (isSelected(name)) remove(name);
  else add(name);
}

function addFromSearch(name: string) {
  add(name);
  query.value = '';
}

function handleEnter() {
  const exact = matches.value.find((name) => name.toLowerCase() === typed.value.toLowerCase());
  if (exact) addFromSearch(exact);
  else if (canAddTyped.value) addFromSearch(typed.value);
}
</script>

<template>
  <div class="flex flex-col">
    <div class="grid gap-x-4.5 gap-y-5 sm:grid-cols-2">
      <section :aria-labelledby="vaultTitleId" class="flex min-w-0 flex-col">
        <h3 :id="vaultTitleId" class="mb-3 text-base font-semibold text-heading">{{ VAULT_SKILLS_FROM_VAULT }}</h3>
        <ul class="flex h-41.5 flex-col gap-1.75 overflow-y-auto rounded-field border border-field-line p-2.75">
          <li v-if="isLoading" class="h-7.75 animate-pulse rounded-sm bg-skill-idle" aria-hidden="true" />
          <li v-else-if="!vaultSkills.length" class="px-1 text-xs text-subtle">{{ VAULT_SKILLS_NONE_IN_VAULT }}</li>
          <li v-for="name in vaultSkills" :key="name">
            <button
              type="button"
              :aria-pressed="isSelected(name)"
              :class="isSelected(name) ? 'bg-tint' : 'bg-skill-idle hover:bg-tint'"
              class="flex min-h-7.75 w-full items-center gap-2 rounded-sm py-1.5 pl-2.75 pr-2.5 text-left text-xs font-semibold text-heading focus-visible:outline-2 focus-visible:outline-brand"
              @click="toggle(name)"
            >
              <span class="min-w-0 flex-1">{{ name }}</span>
              <img
                :src="isSelected(name) ? '/images/vault/skill-check.svg' : '/images/vault/skill-add.svg'"
                alt=""
                :width="isSelected(name) ? 16.464 : 16.9733"
                :height="isSelected(name) ? 17.5 : 16.9733"
              />
            </button>
          </li>
        </ul>
      </section>

      <section :aria-labelledby="aylaTitleId" class="flex min-w-0 flex-col">
        <h3 :id="aylaTitleId" class="mb-3 text-base font-semibold text-heading">
          {{ VAULT_SKILLS_FROM_AYLA }} <span class="text-brand">{{ AYLA_NAME }}</span>
        </h3>
        <ul class="flex h-41.5 flex-col gap-1.75 overflow-y-auto rounded-field border border-field-line p-2.75">
          <li v-if="!aylaSkills.length" class="px-1 text-xs text-subtle">{{ VAULT_SKILLS_NONE_FROM_AYLA }}</li>
          <li v-for="name in aylaSkills" :key="name">
            <button
              type="button"
              :aria-pressed="isSelected(name)"
              :class="isSelected(name) ? 'bg-tint text-heading' : 'bg-brand text-white hover:bg-ink'"
              class="flex min-h-7.75 w-full items-center gap-2 rounded-sm py-1.5 pl-2.75 pr-2.5 text-left text-xs font-semibold focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand"
              @click="toggle(name)"
            >
              <span class="min-w-0 flex-1">{{ name }}</span>
              <img
                :src="isSelected(name) ? '/images/vault/skill-check-ayla.svg' : '/images/vault/skill-add-light.svg'"
                alt=""
                :width="isSelected(name) ? 16.4704 : 16.9767"
                :height="isSelected(name) ? 17.5 : 16.9767"
              />
            </button>
          </li>
        </ul>
      </section>
    </div>

    <label :for="searchId" class="mb-3 mt-6.5 text-base font-semibold text-heading">{{ VAULT_SKILLS_ADD_OWN }}</label>
    <div class="relative">
      <div class="flex h-9.75 items-center gap-4 rounded-field border border-field-line bg-white pl-2.25 pr-3 focus-within:border-brand">
        <img src="/images/vault/search.svg" alt="" width="18" height="18" />
        <input
          :id="searchId"
          v-model="query"
          type="text"
          :maxlength="MAX_SKILL_LENGTH"
          autocomplete="off"
          :placeholder="VAULT_SKILLS_SEARCH"
          class="min-w-0 flex-1 bg-transparent text-[0.8125rem] font-medium text-heading placeholder:text-subtle/40 focus:outline-none"
          @keydown.enter.prevent="handleEnter"
        />
      </div>
      <ul
        v-if="matches.length || canAddTyped"
        class="absolute inset-x-0 top-full z-10 mt-1 flex flex-col rounded-field border border-field-line bg-white p-1 shadow-modal"
      >
        <li v-for="name in matches" :key="name">
          <button
            type="button"
            class="w-full rounded-sm px-2.5 py-2 text-left text-[0.8125rem] font-medium text-heading hover:bg-tile focus-visible:bg-tile focus-visible:outline-2 focus-visible:outline-brand"
            @click="addFromSearch(name)"
          >
            {{ name }}
          </button>
        </li>
        <li v-if="canAddTyped">
          <button
            type="button"
            class="w-full rounded-sm px-2.5 py-2 text-left text-[0.8125rem] font-medium text-brand hover:bg-tile focus-visible:bg-tile focus-visible:outline-2 focus-visible:outline-brand"
            @click="addFromSearch(typed)"
          >
            {{ VAULT_SKILL_ADD_TYPED(typed) }}
          </button>
        </li>
      </ul>
    </div>

    <ul v-if="selected.length" class="mt-7.25 flex flex-wrap gap-x-2 gap-y-1.75" :aria-label="VAULT_SKILLS_SELECTED">
      <li v-for="name in selected" :key="name">
        <button
          type="button"
          :aria-label="`${VAULT_SKILL_REMOVE}: ${name}`"
          :title="VAULT_SKILL_REMOVE"
          class="flex min-h-6.75 items-center rounded-field bg-tile px-2.75 text-[0.8125rem] font-medium text-heading hover:line-through focus-visible:outline-2 focus-visible:outline-brand"
          @click="remove(name)"
        >
          {{ name }}
        </button>
      </li>
    </ul>
  </div>
</template>
