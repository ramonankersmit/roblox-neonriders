# Agent instructions for `src/ServerScriptService`

- Server scripts live here with the double `.server.lua.server.lua` suffix so that both Rojo and Roblox Studio keep the correct ServerScriptService classification. Keep that suffix when adding new server scripts.
- Prefer descriptive PascalCase names that match their Roblox instances (e.g. `GameServer`).
- RemoteEvent names must stay in sync with the values created in `ReplicatedStorage`; avoid renaming without updating clients.
