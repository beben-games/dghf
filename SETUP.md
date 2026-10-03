# Setup

One-time setup for each team member. Delete this file once all three of us are done.

## 1. Everyone: your Claude

1. **Claude Code** is the easiest way to work in the repository: it reads `CLAUDE.md` automatically and can run `git`, `gh` and Godot's command line. Install it, install Godot 4.7.2 stable, clone the repository, and run `gh auth login`.
2. **PixelLab.** Add the PixelLab MCP server to your own user settings, with your own token from pixellab.ai:
   ```
   claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H "Authorization: Bearer <your token>" -s user
   ```
   `-s user` keeps it in your personal settings. Never put your token in a file in the repository.
3. **First task.** Try: "Pick the first open issue in Milestone 1 and work on it."
4. **Brainstorming.** `docs/architecture.md` and much of `docs/game-bible.md` are marked **Proposed**, and `CLAUDE.md` tells Claude to question those points rather than follow them. Start a brainstorm with something like "Let's brainstorm section 5 of the architecture, input". Settled designs go in `docs/design/`.

## 2. Weekly meeting notes

1. **Add the Craig bot** to the Discord server from craig.chat. It records up to 6 hours for free, with a separate audio track for each person, and keeps recordings for 7 days.
2. **Record.** In the voice channel, type `/join` at the start and `/stop` at the end. Craig announces that it's recording and changes its name to show it, so everyone knows. It sends the download link in a private message to whoever started the recording.
3. **Download** the multi-track FLAC zip from that link within 7 days.
4. **Make the notes.** In Claude Code, inside the repository, say "make the meeting notes from" followed by the zip's path. The `meeting-notes` skill in `.claude/skills/` transcribes each track with Whisper on your machine, writes `docs/meetings/<date>.md`, updates the game bible, proposes issues for the action items and opens a pull request. The recording and transcript stay on your machine; only the notes go into the repository.

The first run installs Whisper, which needs Python and `ffmpeg`.

No recording? Type notes in a `#meeting-notes` text channel during the call, then paste them into Claude and ask for meeting notes. The same skill takes it from there.
