# Ayla contract

What the Ayla brain on the server and the apps (web, iPhone, Watch) send each other. The design is in [`docs/ayla.md`](../../docs/ayla.md).

- `reply.schema.json`: the JSON Schema of a request (`$defs/request`) and a reply (the root).
- `request.example.json`: a request from an app.
- `examples/`: example replies. Web and iOS both test that they can read every one of them. Add an example when you add something to the schema.

Rules:

- A change here is a shared change: web and iOS agree on it first.
- Apps skip a block type they do not know yet, so the server can add cards without breaking older apps.
- `usedData` is set by the server and is always part of what the user allowed.
- Vacancies with `"source": "example"` are fictional and the apps label them as examples.
