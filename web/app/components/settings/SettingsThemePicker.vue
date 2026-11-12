<script setup lang="ts">
import type { ThemeId } from '~/utils/settings/appearance';

defineProps<{ customColor: string | null }>();
const theme = defineModel<ThemeId>({ required: true });
const emit = defineEmits<{ custom: [color: string]; commit: [] }>();
const name = useId();

function pickCustomColor(event: Event) {
  emit('custom', (event.target as HTMLInputElement).value.toUpperCase());
}
</script>

<template>
  <!-- The colours share the whole width of the card, so no empty space is left beside them; on a narrow screen the
       row scrolls sideways. -->
  <div class="-mx-3 flex items-center justify-between gap-2.5 overflow-x-auto px-3 py-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
    <div role="radiogroup" :aria-label="PERSONAL_THEME" class="contents">
      <label
        v-for="option in PERSONAL_THEMES"
        :key="option.id"
        :title="option.name"
        :style="{ '--swatch': option.hex, '--ring': option.accent }"
        :class="theme === option.id ? 'border-(--ring) p-1' : 'border-transparent p-0'"
        class="flex size-13 shrink-0 cursor-pointer rounded-full border-2 transition-[padding] has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-brand motion-reduce:transition-none"
      >
        <input v-model="theme" type="radio" :name="name" :value="option.id" class="sr-only" />
        <span class="flex-1 rounded-full bg-(--swatch)" aria-hidden="true" />
        <span class="sr-only">{{ option.name }}</span>
      </label>
    </div>
    <!-- An own colour. Chosen, it looks like the other colours: the colour itself with a ring around it. Not chosen,
         it is the colour wheel, with the last own colour in the middle when there is one. -->
    <label
      :title="PERSONAL_CUSTOM_COLOR_HINT"
      :style="{ '--swatch': customColor ?? 'transparent' }"
      :class="theme === 'custom' && customColor ? 'border-(--swatch) p-1' : 'border-transparent bg-(image:--background-image-color-wheel) p-0'"
      class="relative flex size-13 shrink-0 cursor-pointer items-center justify-center rounded-full border-2 transition-[padding] focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-brand motion-reduce:transition-none"
    >
      <span v-if="theme === 'custom' && customColor" class="size-full rounded-full bg-(--swatch)" aria-hidden="true" />
      <span v-else-if="customColor" class="size-6 rounded-full border-2 border-white bg-(--swatch) shadow-sm" aria-hidden="true" />
      <input type="color" :value="customColor ?? PERSONAL_THEMES[0].hex" :aria-label="PERSONAL_CUSTOM_COLOR_HINT" class="absolute inset-0 size-full cursor-pointer opacity-0" @input="pickCustomColor" @change="emit('commit')" />
    </label>
  </div>
</template>
