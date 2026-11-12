import type { VaultFolder, VaultItem } from '~/types/vault';
import type { Conversation, MemoryNote } from '~/types/ayla';

// Keeps the last fetched vault, chats and memory of Ayla for a quick start (utils/keptData.ts). Everything that changes
// them, a load or something you do yourself, ends up in the shared state; this writes that state away a moment later,
// in one place. Signing out throws it all away.
const WRITE_AFTER_MS = 400;

export default defineNuxtPlugin(() => {
  try {
    const user = useSupabaseUser();
    const vault = useState<{ status: string; items: VaultItem[]; folders: VaultFolder[] } | undefined>('vault');
    const chats = useState<{ status: string; conversations: Conversation[]; canPin: boolean } | undefined>('ayla-chats');
    const memory = useState<{ status: string; notes: MemoryNote[]; isEnabled: boolean } | undefined>('ayla-memory');

    /** Writes a part away once it is ready and has been still for a moment. */
    function keep<T extends { status: string }>(name: string, state: Ref<T | undefined>, pick: (value: T) => unknown) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      watch(
        state,
        (value) => {
          if (!value || value.status !== 'ready') return;
          clearTimeout(timer);
          timer = setTimeout(() => writeKept(name, user.value?.sub, pick(value)), WRITE_AFTER_MS);
        },
        { deep: true },
      );
    }

    keep('vault', vault, (value) => ({ items: value.items, folders: value.folders }));
    keep('chats', chats, (value) => ({ conversations: value.conversations, canPin: value.canPin }));
    keep('memory', memory, (value) => ({ notes: value.notes, isEnabled: value.isEnabled }));

    useSupabaseClient().auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_OUT') clearKept();
    });
  } catch (error) {
    if (import.meta.dev) console.error('The quick start could not be set up', error);
  }
});
