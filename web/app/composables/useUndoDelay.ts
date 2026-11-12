const UNDO_DELAY_MS = 5000;

interface UndoDelayOptions {
  onCommit: (id: string) => void;
  onUndo: (id: string) => void;
}

/**
 * Gives the user a few seconds to undo a delete. Only one delete waits at a time: a new one, or leaving the screen,
 * carries out the waiting one right away.
 */
export function useUndoDelay(options: UndoDelayOptions) {
  const pendingId = ref<string | null>(null);
  let timer: ReturnType<typeof setTimeout> | undefined;

  function takePending() {
    clearTimeout(timer);
    const id = pendingId.value;
    pendingId.value = null;
    return id;
  }

  function commitNow() {
    const id = takePending();
    if (id) options.onCommit(id);
  }

  function schedule(id: string) {
    commitNow();
    pendingId.value = id;
    timer = setTimeout(commitNow, UNDO_DELAY_MS);
  }

  function undo() {
    const id = takePending();
    if (id) options.onUndo(id);
  }

  onBeforeUnmount(commitNow);

  return { pendingId, schedule, undo, commitNow };
}
