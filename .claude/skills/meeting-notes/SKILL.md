---
name: meeting-notes
description: Turn a recording or transcript of the team's weekly Discord meeting into notes in docs/meetings/, update the game bible, and propose GitHub issues for the action items. Use when someone shares a Craig recording, a transcript, or rough notes from a team meeting.
---

# Meeting notes

The team meets weekly on Discord and records the call with the Craig bot, which gives one audio file per speaker. This skill turns that recording, a transcript, or rough typed notes into a notes file in the repository, and proposes issues for what was agreed.

## Privacy rule

This repository is public. Never commit audio files or the full transcript. Work on them in `meetings-raw/`, which `.gitignore` excludes. Only the notes file goes into the repository.

## 1. Get a transcript

Ask the person what they have, if it isn't clear.

- **Rough typed notes or a transcript:** go to step 2.
- **A Craig download** (a zip or folder with one audio file per speaker, each named after the speaker's Discord name): transcribe it.
  1. Unzip into `meetings-raw/YYYY-MM-DD/`.
  2. Check for `whisper` and `ffmpeg`. If `whisper` is missing, install it with `pip install -U openai-whisper`. If `ffmpeg` is missing, tell the person and stop: it is needed to read the audio.
  3. Transcribe each speaker's file separately, with timestamps:
     `whisper <file> --model small --output_format json --output_dir meetings-raw/YYYY-MM-DD/`
     The meetings are usually in French; let Whisper detect the language. On a machine without a GPU this takes a few minutes per file. If the result is poor, rerun with `--model medium`.
  4. Craig's tracks all start at the same moment, so merge them by timestamp: take every segment from every speaker's JSON, sort by start time, and write `meetings-raw/YYYY-MM-DD/transcript.txt` with one line per segment: `[mm:ss] Speaker: text`. Use the speaker names the team uses in the docs (Ben, T, E) where you can match them from the file names; ask the person if you can't.

## 2. Write the notes

Create `docs/meetings/YYYY-MM-DD.md` from `docs/meetings/TEMPLATE.md`, in English.

- **Decisions:** only what the team clearly agreed. Something that was only suggested goes under open questions.
- **Action items:** what, owner and, once created, the issue number. An owner is a person who agreed to it, not someone who was mentioned.
- **Open questions:** anything left unresolved.
- **Changes to the game bible:** each decision that changes something in `docs/game-bible.md`.

Keep it short. The notes record the outcome, not the conversation: no play-by-play, no quotes unless the exact wording matters. Leave out jokes and off-topic chat.

## 3. Update the game bible

Apply the listed changes to `docs/game-bible.md` (and `docs/architecture.md` if the meeting settled a technical question). Mark each point the team agreed on as **Decided** with the meeting date. Ideas that were only discussed stay **Proposed**, and new unanswered questions are added as **Open**.

## 4. Propose issues

For each action item, draft an issue: title, the label for its area (`code`, `art`, `audio`, `writing`, `design`, `level-design`), the milestone, and the assignee. Check the open issues first and update an existing one rather than creating a duplicate.

Show the list to the person and wait for their go-ahead before creating or changing anything on GitHub: the board is shared by all three. Then create them with `gh issue create` and add the issue numbers to the notes.

## 5. Open a pull request

Commit the notes and the game bible changes on a branch named `meeting/YYYY-MM-DD` and open a pull request titled `Meeting notes YYYY-MM-DD`. Tell the person to post the link in Discord so T and E can check the notes.
