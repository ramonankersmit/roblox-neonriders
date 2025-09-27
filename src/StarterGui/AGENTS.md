# Agent instructions for `src/StarterGui`

- Each folder maps to a ScreenGui or UI component. Keep file and instance names aligned.
- Local scripts must keep the `.client.lua` suffix so they remain LocalScripts when synced.
- UI logic should avoid direct waits for `ReplicatedStorage` objects; rely on events exposed by the server code instead.
