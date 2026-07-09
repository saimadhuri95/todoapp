# Launch & ASO Playbook

This doc closes TASKS.md 4.13, 4.14, and 4.15:

- Google Play metadata copy
- a coordinated launch-velocity plan
- the per-release App Store optimization loop

## 1. Google Play metadata (4.13)

Google Play gives us:

- a 30-character title
- an 80-character short description
- a 4,000-character full description

Unlike Apple, Play also indexes the description, so this copy can carry
search intent that does not fit cleanly into the title.

### Title

`Knot: Todo List & Private Sync`

- 30 / 30 characters
- keeps the brand
- covers "todo list"
- adds the differentiator "private sync"

### Short description

`Private todo app with encrypted sync, reminders, and no account required.`

- 73 / 80 characters
- leads with privacy, sync, reminders, and no-account setup

### Full description

```text
Knot is a local-first todo app for Android, iPhone, iPad, Mac, Windows, and
Linux. Your tasks stay on your devices and sync directly between them - over
Wi-Fi or through a cloud folder you already use - with no account and no
central server run by us.

Use Knot when you want a private todo list that still works across devices:

- Keep personal tasks available offline on every device
- Share one trusted dataset across your own phones, tablets, and laptops
- Manage grocery, packing, errands, and household checklists without another
  SaaS account
- Use reminders and alarms without moving your task data into a hosted backend

Why people pick Knot

- Offline-first todo list: every device keeps the full database locally
- Private sync: pair devices with a QR code; synced mailbox files are encrypted
- No account: no signup, no central server, no lock-in
- Free-with-privacy: no subscription, no tracking account, and no hosted
  service required
- Cross-platform: Android, iOS, macOS, Windows, and Linux
- Real reminders: mobile alarms today, desktop reminders where the platform
  supports them

Sync options

- Direct LAN sync when devices are on the same network
- Encrypted sync through iCloud Drive, Google Drive, Dropbox, Syncthing, or
  another synced folder you already trust

Good to know

- Knot stays fully usable on one device even if you never pair anything
- Paired devices intentionally share the same full dataset in v1
- Knot is source-available for reading and contribution; redistribution needs
  written permission
- "Free" describes the intended user experience, not permission for third
  parties to redistribute or repackage the app

If you want a private, serverless todo app with encrypted cross-device sync,
Knot is built for that.
```

## 2. Launch-velocity plan (4.14)

Goal: concentrate the first 24-48 hours of installs, comments, and shares
while the listing is fresh instead of spreading the attention spike across
multiple days.

### Preconditions

- App Store / Play metadata is final
- screenshots and preview assets are ready
- GitHub release notes are ready
- download or install paths have been tested end to end
- campaign links exist for every external channel we plan to use
- somebody is available to reply quickly on launch day

### T-14 to T-7

- Create or refresh the Product Hunt account early.
  Product Hunt requires newly created accounts to wait one week before
  posting and recommends showing up earlier than that.
- Draft the Product Hunt assets:
  tagline, description, gallery, first maker comment, FAQ answers.
- Draft the Show HN post around what Knot is, how it works, and what people
  can try immediately.
- Draft a self-hosted angle for Reddit that stays honest:
  "no central server, local-first, your own synced folder", not vague
  "productivity app" promotion.
- Prepare screenshots that match the launch thesis:
  private sync, no account, works across devices.
- Create campaign links for Product Hunt, Hacker News, Reddit, direct social,
  and GitHub release traffic.

### T-2 to T-0

- Ship the release candidate and verify the actual listing, download links,
  and screenshots, not just the source repo.
- Schedule the Product Hunt launch for the same day the listing goes live.
- Keep Hacker News and Reddit drafts ready, but do not post until the app is
  available and the install path works.
- Block uninterrupted response time for the first launch window.

### Launch day sequence

1. Publish the release and confirm the install path is live.
2. Publish Product Hunt first, then immediately add the maker comment:
   what Knot is, why it is serverless, and which platforms are ready now.
3. Once the product page and download path are stable, post Show HN.
   Show HN works best when people can try the thing right away.
4. Post to `r/selfhosted` only after checking the current subreddit rules
   that day; if the fit is weak or the rules are unclear, skip it.
5. Reply quickly to early comments and questions.
6. Record the repeated objections or confusions; those become screenshot,
   FAQ, and onboarding improvements for the next release.

### Channel notes

- Product Hunt:
  use the launch dashboard to watch ranking, comments, and reviews in one
  place, and keep the maker comment updated.
- Show HN:
  keep the post factual and technical; emphasize architecture, privacy,
  and something runnable or downloadable today.
- Reddit:
  one high-context post beats several cross-posted launch blasts.

### What not to do

- Do not split the spike across several days.
- Do not launch before the install path is smooth.
- Do not promise roadmap items that are not shipped.
- Do not let store copy, screenshots, and launch posts tell different stories.

## 3. Post-launch ASO loop (4.15)

Goal: every release should improve either discovery, conversion, or both.

### Metrics to review in App Store Connect

From App Analytics, review:

- impressions
- unique impressions
- product page views
- unique product page views
- conversion rate
- total downloads
- first-time downloads
- redownloads
- source type splits such as search, browse, referrals, and campaign links

App Store Connect's Analytics dashboard is also organized around acquisition
questions such as Sources and Product Pages, so use those views before trying
to infer everything from the top-line totals.

### Per-release loop

1. Write one hypothesis before each release.
   Example: "private sync converts better than collaborative wording."
2. Log exactly what shipped:
   name, subtitle, keywords, screenshots, promotional text, and campaign links.
3. Check the results after 72 hours, 7 days, and 28 days.
4. Queue keyword changes for the next version.
   Use promotional text or custom product pages for interim experiments when
   that is enough; save keyword changes for the next app version.
5. Change as few variables as possible per release so the result is legible.

### Decision rules

- Low impressions plus healthy conversion:
  discovery problem. Tighten title, subtitle, keywords, or screenshot search
  alignment.
- High impressions plus weak conversion:
  product-page problem. Fix screenshot one, subtitle clarity, and first-screen
  value proposition.
- Search traffic weak but referrals strong:
  keep community launches and direct links in the mix; the listing may be
  fine, but query matching is off.
- Search traffic high but low-intent:
  remove generic keywords that attract the wrong audience and lean harder into
  "private", "sync", "offline", and "serverless" positioning.
- Installs healthy but retention weak:
  improve onboarding and first-run clarity before spending effort on more
  traffic.

### Release log template

| Release | Hypothesis | Metadata changed | Campaigns run | 72h result | 7d result | Next change |
|---|---|---|---|---|---|---|
| v0.x.y |  |  |  |  |  |  |
