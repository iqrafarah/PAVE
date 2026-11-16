const STORAGE_KEY = 'ayla-voice-text';

/**
 * "Tekst bij praten met Ayla" (iOS AylaVoiceTextSetting): whether the caption shows under the orb. Like on the
 * iPhone it belongs to this device, so it is kept in this browser. On by default.
 */
export function useAylaVoiceText() {
  const showsVoiceText = useState('ayla-voice-text', () => true);

  function load() {
    try {
      showsVoiceText.value = localStorage.getItem(STORAGE_KEY) !== 'off';
    } catch {
      // Storage is blocked: the caption stays on.
    }
  }

  function set(isOn: boolean) {
    showsVoiceText.value = isOn;
    try {
      localStorage.setItem(STORAGE_KEY, isOn ? 'on' : 'off');
    } catch {
      // Storage is blocked: the choice works until the page is closed.
    }
  }

  return { showsVoiceText, load, set };
}
