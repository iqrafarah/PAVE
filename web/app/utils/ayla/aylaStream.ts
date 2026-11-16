export interface StreamEvent {
  name: string;
  data: unknown;
}

/**
 * Reads server-sent events from text that arrives in pieces. Keep the returned `rest` and pass it with the next
 * piece: a line can be split over two pieces.
 */
export function readStreamEvents(rest: string, piece: string, currentName: string) {
  const lines = (rest + piece).split('\n');
  const nextRest = lines.pop() ?? '';
  const events: StreamEvent[] = [];
  let name = currentName;

  for (const line of lines) {
    if (line.startsWith('event:')) name = line.slice(6).trim();
    if (!line.startsWith('data:')) continue;
    events.push({ name, data: parseData(line.slice(5)) });
  }
  return { events, rest: nextRest, name };
}

function parseData(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}
