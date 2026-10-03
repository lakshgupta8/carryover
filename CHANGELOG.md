# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-03

First release.

### Added
- Email/password and Google sign-in via Firebase Auth; data in Firestore with
  per-user security rules; offline-first.
- Habits with emoji, reminder time and two schedule types: specific weekdays,
  or *n* days a week on any days (streak breaks only after more than 7 − n
  skips in a week).
- On-device exact-alarm reminders with a **Mark done** action that works from
  the notification shade even when the app is closed; optional evening
  check-in.
- Streaks: per habit, daily (perfect days), weekly and monthly.
- Two-tier tokens: a wallet per habit (check-ins, that habit's milestones) and
  a shared wallet (perfect days, global milestones, exchanges). 2 : 1 one-way
  exchange.
- Repairs: buy back a missed day for 10 tokens per habit, paid habit-wallet
  first; weekly habits repair the extra skipped days only.
- Milestones with one-time bonuses and a celebration: daily, weekly, monthly,
  check-in totals and per-habit tiers.
- Configurable day boundary (midnight to 5 AM) and grace period for ticking
  yesterday's habits for free.
- Rewards tab with balance breakdown, habit wallets, tappable 12-week heatmap,
  lifetime stats and milestone progress.
- Drag to reorder habits, any-emoji picker, haptics, bundled fonts, JSON
  export, account deletion.
