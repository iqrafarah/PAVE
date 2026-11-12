/** A temporary link to a picked file, to show it before it is uploaded. It is let go again when the file changes. */
export function useObjectUrl(file: MaybeRefOrGetter<File | null | undefined>) {
  const url = ref<string | null>(null);
  watch(
    () => toValue(file),
    (current) => {
      if (url.value) URL.revokeObjectURL(url.value);
      url.value = current && import.meta.client ? URL.createObjectURL(current) : null;
    },
    { immediate: true },
  );
  onBeforeUnmount(() => {
    if (url.value) URL.revokeObjectURL(url.value);
  });
  return url;
}
