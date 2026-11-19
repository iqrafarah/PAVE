<script setup lang="ts">
// The light green tray around the chat composer and the choice bar (Figma "Rectangle 35", 608 x 101).
// The strip above the content holds the files added to the question. Without a strip (plain Ja / Nee) the tray has no
// empty space on top and is a simple rounded bar.
const slots = useSlots();
const hasStrip = computed(() => Boolean(slots.strip));
</script>

<template>
  <div class="ayla-tray relative w-full max-w-152" :class="hasStrip ? '' : 'rounded-[1.75rem] bg-tint'">
    <!-- The shape fades in with the strip, so it is never seen squashed while the strip is still opening. -->
    <Transition name="tray-shape" appear>
      <VaultIcon v-if="hasStrip" src="/images/ayla/tray.svg" stretch class="absolute inset-x-0 top-0 h-full w-full text-tint" />
    </Transition>
    <Transition name="strip" appear>
      <div v-if="hasStrip" class="relative grid grid-rows-[1fr]">
        <div class="min-h-0 overflow-hidden">
          <div class="flex min-h-9.75 flex-wrap items-center gap-2 px-14 pt-2">
            <slot name="strip" />
          </div>
        </div>
      </div>
    </Transition>
    <div class="relative px-2 pb-2" :class="hasStrip ? '' : 'pt-2'">
      <slot />
    </div>
  </div>
</template>
