<script setup lang="ts">
// The top of an employer's page in its own look, like its poster at the stand.
const props = defineProps<{ brand: FairBrand; name: string; city?: string; stand?: string }>();
const letter = computed(() => props.stand?.split(' ').pop() ?? '');
const standLabel = computed(() => (props.brand.mono ? props.stand?.replace('Stand ', 'stand_') : props.stand));
const headline = computed(() => props.brand.headline.split('\n'));
</script>

<template>
  <section
    class="relative isolate overflow-hidden rounded-3xl p-6 sm:p-8"
    :style="{ background: brand.background, color: brand.ink }"
  >
    <svg v-if="brand.motif === 'chevron'" aria-hidden="true" class="absolute right-5 top-[58%] -z-10 h-[50%] -translate-y-1/2" viewBox="0 0 140 160">
      <path d="M0 0h60l80 80-80 80H0l80-80z" fill="#EC1C24" />
    </svg>
    <template v-else-if="brand.motif === 'sun'">
      <div aria-hidden="true" class="absolute inset-0 -z-10 bg-[linear-gradient(rgba(255,255,255,.07)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.07)_1px,transparent_1px)] bg-size-[20px_20px]" />
      <svg aria-hidden="true" class="absolute -right-4 -top-4 -z-10 size-40" viewBox="-80 -80 160 160">
        <g :stroke="brand.accent" stroke-linecap="round">
          <line v-for="i in 24" :key="i" :x1="Math.cos(i / 24 * 2 * Math.PI) * 42" :y1="Math.sin(i / 24 * 2 * Math.PI) * 42" :x2="Math.cos(i / 24 * 2 * Math.PI) * (i % 2 ? 64 : 78)" :y2="Math.sin(i / 24 * 2 * Math.PI) * (i % 2 ? 64 : 78)" :stroke-width="i % 2 ? 2.5 : 4.5" />
          <circle r="28" fill="none" stroke-width="7" />
        </g>
        <text y="11" text-anchor="middle" fill="#fff" font-size="30" font-weight="900">{{ letter }}</text>
      </svg>
    </template>
    <svg v-else-if="brand.motif === 'rings'" aria-hidden="true" class="absolute right-[-210px] top-[-220px] -z-10 size-[500px]" viewBox="-250 -250 500 500">
      <circle r="250" :fill="brand.accent" opacity=".10" /><circle r="190" fill="#fff" opacity=".14" /><circle r="130" :fill="brand.accent" opacity=".18" />
    </svg>
    <p v-else-if="brand.motif === 'band'" aria-hidden="true" class="absolute right-[-10px] top-[-40px] -z-10 text-[260px] font-black leading-none text-black/10">{{ letter }}</p>
    <svg v-else aria-hidden="true" class="absolute inset-0 -z-10 size-full" preserveAspectRatio="none">
      <defs>
        <pattern id="fair-zigzag" width="52" height="44" patternUnits="userSpaceOnUse">
          <path d="M-13 30 13 14 39 30 65 14" fill="none" stroke="#fff" stroke-opacity=".2" stroke-width="12" />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#fair-zigzag)" />
    </svg>

    <div class="flex items-start justify-between gap-3">
      <img
        :src="brand.logo" :alt="name" width="170" height="52"
        class="h-13 w-auto" :class="brand.motif === 'band' ? '' : 'px-3 py-2'"
        :style="{ background: brand.motif === 'band' ? 'transparent' : '#fff', borderRadius: brand.plateRadius }"
      >
      <p
        v-if="stand && brand.motif !== 'sun'"
        class="text-sm font-bold"
        :class="brand.mono ? 'font-mono' : 'rounded-full px-3 py-1.5'"
        :style="brand.motif === 'chevron' ? { color: brand.accent } : brand.motif === 'band' ? { background: brand.accent, color: '#fff' } : { background: '#fff', color: brand.background }"
      >{{ standLabel }}</p>
    </div>
    <p v-if="brand.kicker" class="mt-6 font-mono text-sm" :style="{ color: brand.accent }">{{ brand.kicker }}</p>
    <h1
      v-if="brand.motif === 'band'"
      class="-mx-12 my-6 -rotate-3 bg-black px-12 py-3 text-center text-3xl font-black uppercase sm:text-4xl"
      :style="{ color: brand.background }"
    >{{ brand.headline }}</h1>
    <h1 v-else class="text-4xl font-extrabold leading-[1.05] sm:text-5xl" :class="[brand.uppercase ? 'uppercase' : 'tracking-tight', brand.kicker ? 'mt-1' : 'mt-6']">
      <span v-for="line in headline" :key="line" class="block">{{ line }}</span>
    </h1>
    <p class="mt-4 text-sm font-semibold opacity-85">{{ [name, city].filter(Boolean).join(' · ') }}</p>
  </section>
</template>
