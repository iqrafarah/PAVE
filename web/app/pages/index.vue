<script setup lang="ts">
definePageMeta({ showsChats: true });
useHead({ title: 'Ayla - PAVE' });

// Kluis, Plan and Profiel (Figma Start: three pills under the intro); their screens are still empty, as on the iPhone.
const LATER_SHORTCUTS = [
  {
    label: 'Kluis',
    path: '/kluis',
    icon: '/images/ayla/pill-vault.svg',
    width: 20.3,
    height: 18,
  },
  {
    label: 'Plan',
    path: '/plan',
    icon: '/images/ayla/pill-plan.svg',
    width: 19.5,
    height: 19.2,
  },
  {
    label: 'Profiel',
    path: '/profiel',
    icon: '/images/ayla/pill-profile.svg',
    width: 14,
    height: 17,
  },
];

const conversation = useAylaConversation();
const { getAccount } = useAyla();

const firstName = ref<string | null>(null);
const isAccountLoaded = ref(false);

const heading = computed(() => getHomeHeading(firstName.value));

onMounted(async () => {
  conversation.startNew();
  const account = await getAccount();
  firstName.value = account.firstName;
  isAccountLoaded.value = true;
});
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col">
    <AylaTitleBar :shows-title="false" />
    <AylaChatView>
      <template #empty>
        <div
          class="flex flex-1 flex-col items-center justify-center overflow-y-auto px-4 py-8 text-center"
        >
          <AylaTypingTitle :text="heading" :is-ready="isAccountLoaded" />
          <p class="mt-3 max-w-105.25 text-sm font-medium text-subtle">
            {{ AYLA_HOME_INTRO }}
          </p>
          <ul class="mt-5.75 flex flex-wrap justify-center gap-3.5">
            <li v-for="shortcut in LATER_SHORTCUTS" :key="shortcut.label">
              <NuxtLink
                :to="shortcut.path"
                class="inline-flex h-10.75 items-center gap-1.5 rounded-pill bg-tint px-4.75 font-heading text-xs font-semibold text-heading hover:bg-brand-soft focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              >
                <img
                  :src="shortcut.icon"
                  alt=""
                  :width="shortcut.width"
                  :height="shortcut.height"
                />
                {{ shortcut.label }}
              </NuxtLink>
            </li>
          </ul>
        </div>
      </template>
    </AylaChatView>
  </div>
</template>
