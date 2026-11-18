import type { VaultFile } from '~/types/vault';

/** The file shown in the preview over the page ("Bestand bekijken"); null while there is none. */
export function useFilePreview() {
  const file = useState<VaultFile | null>('vault-file-preview', () => null);
  return {
    file,
    open: (next: VaultFile) => (file.value = next),
    close: () => (file.value = null),
  };
}
