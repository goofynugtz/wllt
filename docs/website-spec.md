# WLLT — Marketing Website Spec

**Date:** 2026-05-26  
**Purpose:** Spec for a conversion-focused marketing website. Three pages: Landing, Terms of Use, Privacy Policy.

---

## App Summary (for generator context)

**App name:** WLLT  
**Tagline:** "Track your expenses, master your money."  
**Platform:** iOS + Android (Flutter)  
**Audience:** Individuals who want effortless, intelligent expense tracking — especially Indian users with bank SMS, but globally targeted.

**Core differentiators:**
1. **SMS auto-detection** — reads bank SMS messages, auto-extracts transactions, queues them for one-tap confirmation. No manual entry for bank spends.
2. **On-device AI** — Gemma 3 1B runs fully on your phone. Smart categorization + monthly spending summaries + insights. Zero data leaves the device.
3. **Per-category budgets** — weekly or monthly limits with live progress bars.
4. **Cloud sync** — Google sign-in + Firestore backup. Offline mode also available.

**Monetization:** 30-day free trial, then subscription. Beta users get 1 year free via promo codes.

---

## Site Architecture

```
/              → Landing (Home)
/terms         → Terms of Use
/privacy       → Privacy Policy
```

Optional future:
```
/blog          → (not in scope now)
/support       → (not in scope now)
```

---

## Content Rules

**No emojis anywhere on the website.** Not in headings, body copy, bullet points, buttons, badges, or UI mockup strings. Use icons (SVG) where a visual indicator is needed. Emojis render inconsistently across OS/browser and undermine the premium, trustworthy tone the app requires.

---

## Design Language

| Token | Value |
|-------|-------|
| Primary accent | `#6750A4` (deep purple) |
| Surface warm | `#FFF3F0` (warm blush, 91% opacity over white) |
| Dark neutral | `#1D1B20` |
| Muted text | `#6B6572` |
| Error/highlight | `#E63946` |
| Success | `#70C01F` |
| Font — headings | Archia (fallback: Sora, then system-ui sans-serif) |
| Font — body | Inter (fallback: system-ui sans-serif) |
| Border radius | Cards: 24px. Buttons: 50px (full pill). Sheet-style: 36px top |
| Shadow style | Soft ambient, 0 8px 32px rgba(0,0,0,0.08) |

**Visual motif:** The app uses warm blush + deep purple. The website should carry the same warmth but feel premium and spacious. Think: a modern fintech app — clean, trustworthy, not cold.

**Wow factor source:** The hero section should immediately show the product in action with a phone mockup + animated floating transaction cards (SMS → card → confirmed). Motion conveys the "automatic" magic of the core feature before a word is read.

---

---

# PAGE 1: Landing (/)

## Section 1 — Hero

**Layout:** Full viewport height (100vh). Two-column on desktop (text left, phone right). Stacked on mobile (text top, phone bottom, phone partially clipped at bottom edge for scroll intrigue).

**Background:** Subtle animated gradient — warm blush `#FFF3F0` bleeding into soft purple `#EDE7F6`. Very slow drift (60s cycle). Not distracting.

**Left column — copy:**

```
OVERLINE (12px, uppercase, tracked, muted):
  Track · Budget · Understand

HEADLINE (64px desktop / 40px mobile, Archia, weight 700, line-height 1.1):
  Your money,
  on autopilot.

SUBLINE (18px, Inter, muted #6B6572, max-width 480px):
  WLLT reads your bank messages, spots every transaction,
  and gives you AI-powered insights — all on your device.
  No subscriptions to start. No data leaving your phone.

CTA ROW (gap 12px):
  [App Store button]   [Google Play button]
  Both: dark pill #1D1B20, white logo + text, 52px height

SOCIAL PROOF LINE (12px, muted, below CTAs):
  ★★★★★  Loved by 500+ beta testers
```

**Right column — Phone mockup:**

A phone frame (device mockup, centered) showing the app's home screen. On top of/around the phone, floating UI fragments animate in:

- An SMS notification card floats in from the right: `"HDFCBK: Rs.349 debited for UPI to Zomato"` — styled like a real notification.
- An arrow/flow line connects it to a transaction card below.
- A confirmation card pops into the phone screen: `Zomato · ₹349 · Restaurant ✓` with a green checkmark pulse.
- This mini-animation loops every 6 seconds (SMS → parse → confirm).

Animation library: **GSAP** (GreenSock). Use `gsap.timeline()` for the SMS→parse→confirm sequence. Keep it subtle — no flashy particles, just purposeful motion.

**Scroll indicator:** Animated chevron-down at the bottom center, fades out on first scroll.

---

## Section 2 — Feature: SMS Auto-Detection

**Layout:** Alternating layout (text left, visual right on desktop). Full width on mobile.

**Visual:** Phone mockup showing the SMS Inbox sheet (bell icon + pending transaction cards with inline edit UI). Animate a card swiping right to confirm.

**Copy:**

```
LABEL: Automatic capture
HEADLINE (40px, Archia): Your bank texts you.
                          We take notes.

BODY (16px, Inter, muted):
  WLLT scans your bank messages in the background
  and pulls out every transaction — merchant, amount,
  category — before you even open the app.
  
  Review in seconds. One swipe to confirm.

BULLETS (with icon):
  ✦  Works with all major Indian banks
  ✦  Filters spam, OTPs, and promos automatically
  ✦  Fraud detection flags suspicious senders
  ✦  No message leaves your phone
```

---

## Section 3 — Feature: On-Device AI

**Layout:** Alternating (text right, visual left on desktop).

**Visual:** Abstract but beautiful — a stylized brain/chip graphic made from the app's category icons arranged in a neural-network-style pattern. OR: phone mockup showing a Monthly Summary card ("In April you spent ₹31,914 — 37% of your income. Dining out was your biggest change.") with a subtle shimmer indicating AI-generated content.

**Copy:**

```
LABEL: Private by design
HEADLINE (40px, Archia): AI that lives
                          on your phone.

BODY (16px, Inter, muted):
  Our on-device AI (Gemma 3 1B) learns your spending
  patterns and surfaces insights — completely offline.
  
  No cloud. No server. No one reads your data.
  Not even us.

BULLETS:
  ✦  Smart category suggestions as you type
  ✦  Monthly narrative spending summary
  ✦  Weekly actionable insights
  ✦  Available on Premium plan
  
DISCLAIMER (11px, muted):
  AI model downloads once (~600 MB) to your device.
  Requires Premium plan.
```

---

## Section 4 — Feature: Budgets

**Layout:** Centered, full-width card with soft background. Not alternating — this section uses a 3-up card grid to show 3 categories with progress bars.

**Visual:** Three rounded cards side by side (or stacked on mobile):
- Card 1: "Restaurant · ₹3,200 / ₹3,000 · ⚠ Over budget" — progress bar red
- Card 2: "Groceries · ₹1,840 / ₹4,000" — progress bar green, 46%
- Card 3: "Shopping · ₹5,100 / ₹6,000" — progress bar yellow-green, 85%

Cards should look like the app's actual category detail screens (warm, colorful, rounded).

**Copy:**

```
LABEL: Stay in control
HEADLINE (40px, Archia): Set limits.
                          See them live.

BODY (16px, Inter, muted):
  Create weekly or monthly budgets for any category.
  A live progress bar shows exactly where you stand —
  before you overspend, not after.
```

---

## Section 5 — How It Works (3-step flow)

**Layout:** Centered, 3 columns on desktop, vertical on mobile. Each step: number (large, purple, background), icon, title, description.

```
STEP 1
Icon: phone/message
Title: Your bank sends an SMS
Body: Every transaction triggers a notification from your bank.
      WLLT catches it automatically in the background.

STEP 2
Icon: sparkle/wand
Title: We parse it instantly
Body: Merchant, amount, category — extracted and ready
      for your review. No typing needed.

STEP 3
Icon: check-circle
Title: You confirm in one tap
Body: Swipe right on the card or tap confirm. Done.
      Your expense is logged and categorized.
```

Between steps: subtle dashed arrow connectors (desktop only).

---

## Section 6 — Pricing / CTA

**Layout:** Centered, full-width, dark background `#1D1B20` (contrast section to break the page).

**Copy:**

```
OVERLINE (muted white/40%): Simple pricing

HEADLINE (48px, Archia, white): Start free.
                                 Stay in control.

SUBLINE (18px, white/70%):
  30 days free — no credit card required.
  After that, a small subscription keeps the lights on.
  Beta testers get one full year, on us.

TWO CARDS (side by side, rounded 24px):

  CARD 1 — Free Trial
  Background: white/10% (glass)
  Label: FREE
  Duration: First 30 days
  Features list:
    ✓ Manual expense entry
    ✓ All 18 categories
    ✓ SMS auto-detection
    ✓ Per-category budgets
    ✓ CSV / PDF export
    ✓ Cloud sync
  CTA: [Download Free] — white pill button

  CARD 2 — Premium  (highlighted with purple border)
  Label: PREMIUM  ← pill badge "Most popular"
  Price: Coming soon (beta pricing TBD)
  Features: Everything in Free, plus:
    ✓ On-device AI insights
    ✓ Smart categorization
    ✓ Monthly spending summaries
    ✓ Priority support
  CTA: [Join the waitlist] — purple pill button

BETA NOTE (below cards, muted white):
  Currently in beta. Use a promo code at signup for 1 year free.
```

---

## Section 7 — Trust / Privacy Statement

**Layout:** Two-column (icon-rich list left, statement right). Light background, soft divider from previous section.

```
LEFT — TRUST SIGNALS (with icons):
  🔒 Your data stays on your device
  📵 No SMS content uploaded anywhere
  🇮🇳 Built for Indian banking, global at heart
  🛡 Suspicious SMS flagged, fraudulent ones blocked
  ☁ Cloud sync only when you sign in with Google
  📤 Export your data anytime

RIGHT — STATEMENT:
  HEADLINE (28px, Archia):
    We built WLLT the way
    we'd want it built for us.

  BODY (16px, muted):
    Expense apps have access to some of your most
    sensitive information. We take that seriously.
    
    The on-device AI never sends your spending data
    to a server. SMS parsing runs locally. Cloud sync
    is opt-in. You can export everything and leave
    anytime.
    
    We earn through subscriptions, not your data.
```

---

## Section 8 — Footer

```
Logo: WLLT (wordmark, 20px, Archia)
Tagline: Track your expenses, master your money.

Links (horizontal, 14px):
  Privacy Policy · Terms of Use · Contact

Social / App Store:
  [App Store badge]  [Google Play badge]

Copyright:
  © 2026 WLLT. All rights reserved.
```

---

---

# PAGE 2: Terms of Use (/terms)

## Layout

Simple document page. Max-width 720px, centered. Large readable body type (17px Inter). Section headers 22px Archia. Purple accent on section numbers/links. Top nav bar (WLLT logo → home, "Privacy Policy" link).

## Content Outline

**Last updated:** [date of publication]

---

### 1. Acceptance of Terms

By downloading, installing, or using WLLT ("the App"), you agree to be bound by these Terms of Use. If you do not agree, do not use the App.

---

### 2. Description of Service

WLLT is a personal expense tracking application for iOS and Android. The App allows you to:

- Manually log and categorize financial transactions
- Automatically detect transactions from bank SMS messages (Android only, with your permission)
- Set category-based spending budgets
- Generate AI-powered spending insights entirely on-device
- Sync your data to the cloud via Google Sign-In (optional)
- Export your data as CSV or PDF

WLLT is a personal finance management tool. It is **not** a bank, financial advisor, investment advisor, or any kind of regulated financial institution. Nothing in the App constitutes financial advice.

---

### 3. Eligibility

You must be at least 13 years old to use WLLT. If you are between 13 and 18, you must have permission from a parent or legal guardian. By using the App, you confirm that you meet these requirements.

---

### 4. User Accounts

**Google Sign-In (optional):** You may sign in with a Google account to enable cloud sync. By doing so, you authorize WLLT to store your expense data in Firebase (Google Cloud) associated with your Google account ID. You remain responsible for your Google account security.

**Offline Mode:** You may use WLLT without creating an account. In offline mode, data is stored locally on your device only. If you uninstall the App or lose your device, data in offline mode cannot be recovered.

---

### 5. Free Trial and Subscription

- The App offers a **30-day free trial** upon first installation. No payment method is required to begin the trial.
- After the trial period, continued use of the full App requires an active **Premium subscription**, priced and billed as described in the App Store or Google Play listing at time of purchase.
- Subscriptions are managed by Apple App Store or Google Play. Billing, cancellation, and refund policies are governed by their respective terms.
- **Promo codes** may be issued for extended free access. Promo codes are single-use, non-transferable, and may be revoked if obtained fraudulently.
- Free features remain accessible after the trial ends. Premium features (on-device AI, [others as defined in-app]) require an active subscription.

---

### 6. SMS Permissions (Android)

If you grant WLLT permission to read SMS messages on Android, the App will:

- Read SMS messages from your inbox to detect bank transaction messages.
- Process SMS content locally on your device.
- **Never upload raw SMS content to any server.**
- Apply fraud and spam filtering to discard non-financial, OTP, and suspicious messages.
- Store parsed transaction data (merchant, amount, category) locally or in your cloud account if sync is enabled.

You may revoke SMS permission at any time via your device settings. The App will continue to function without SMS access; you will simply need to log transactions manually.

---

### 7. On-Device AI Features

Premium subscribers may optionally download an AI language model (~600 MB) that runs entirely on their device:

- The model is used for transaction categorization, SMS parsing assistance, and spending summaries.
- **No data is sent to any server during AI inference.** The model runs locally.
- The model download requires internet access and approximately 600 MB of device storage.
- You may delete the model at any time from Settings. Doing so frees storage but disables AI features until re-downloaded.

---

### 8. Prohibited Uses

You agree not to:

- Use the App to process or track financial transactions on behalf of others without their knowledge
- Attempt to reverse-engineer, decompile, or extract the App's source code
- Use the App in any way that violates applicable laws or regulations
- Attempt to gain unauthorized access to any backend systems associated with the App
- Resell, sublicense, or commercially exploit the App

---

### 9. Data Accuracy

WLLT relies on your inputs and automated SMS parsing. Transaction data shown in the App may be incomplete, incorrectly parsed, or miscategorized. You are responsible for reviewing and correcting your financial records. Do not rely solely on WLLT for tax, legal, or financial decisions.

---

### 10. Intellectual Property

All content, design, code, and trademarks associated with WLLT are owned by or licensed to WLLT's developers. You are granted a limited, non-exclusive, non-transferable license to use the App for personal, non-commercial purposes.

---

### 11. Disclaimers

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. WE DO NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR THAT DEFECTS WILL BE CORRECTED. USE OF THE APP IS AT YOUR SOLE RISK.

---

### 12. Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, WLLT AND ITS DEVELOPERS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES — INCLUDING LOSS OF DATA OR FINANCIAL LOSS — ARISING OUT OF OR RELATED TO YOUR USE OF THE APP, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

---

### 13. Changes to These Terms

We may update these Terms at any time. Material changes will be communicated via in-app notice or email (if provided). Continued use of the App after changes constitutes acceptance. If you disagree with updated Terms, your remedy is to stop using the App and cancel any active subscription.

---

### 14. Governing Law

These Terms are governed by the laws of India, without regard to conflict-of-law provisions. Disputes shall be resolved in the courts of [City, State — fill in at publication].

---

### 15. Contact

Questions about these Terms: [legal contact email — fill at publication]

---

---

# PAGE 3: Privacy Policy (/privacy)

## Layout

Same as Terms page. Same nav. Different section structure.

## Content Outline

**Last updated:** [date of publication]

WLLT ("we," "us," "our") is committed to protecting your privacy. This Privacy Policy explains what information we collect, how we use it, and your rights.

---

### 1. Information We Collect

#### 1a. Information You Provide

- **Transactions:** Merchant names, amounts, dates, categories, and notes you enter manually.
- **Account names:** Names you give to your payment accounts (e.g., "HDFC Savings"). We do not collect actual account numbers.
- **Google account info (if you sign in):** Your Google user ID and email address, used to identify your cloud data. We do not access your Google account beyond what you explicitly authorize.

#### 1b. Information Collected Automatically

- **SMS content (Android, opt-in):** If you grant SMS permission, we read bank SMS messages locally to detect transactions. Raw SMS text is **never uploaded** to any server. Only parsed data (merchant, amount, category) may be stored and synced.
- **Device identifiers:** Anonymous installation ID for crash reporting and analytics (non-personal).
- **App usage patterns:** Aggregate, anonymized analytics (e.g., which screens are used, error rates). Not tied to your identity.

#### 1c. Information We Do NOT Collect

- Bank account numbers, card numbers, PINs, or passwords
- Location data
- Contacts or call logs
- Any biometric data
- Raw SMS text outside of local processing

---

### 2. How We Use Your Information

| Data | Purpose |
|------|---------|
| Transaction data | Core app functionality — display, budgets, export, summaries |
| Google account ID | Cloud sync — link your data to your account in Firestore |
| Google email | Display in Settings; contact for account-related issues |
| Anonymized analytics | Improve app stability and features |
| SMS content (local) | Extract transaction data; never stored as raw text |

We do **not** sell your data. We do not use your financial data for advertising targeting.

---

### 3. On-Device AI Processing

If you enable AI features (Premium):

- A language model (Gemma 3 1B, ~600 MB) is downloaded once to your device.
- All AI inference runs locally. No transaction data, SMS content, or spending patterns are sent to any server during AI processing.
- The model file itself is downloaded from Google's servers (standard model distribution). The download is subject to Google's standard infrastructure.

---

### 4. Cloud Sync (Google Sign-In users)

If you choose to sign in with Google:

- Your transaction, account, category, and budget data is stored in **Firebase Firestore** (Google Cloud), associated with your Google user ID.
- Firebase is subject to Google's data processing terms. See [Firebase Privacy](https://firebase.google.com/support/privacy).
- Data is encrypted in transit (TLS) and at rest.
- You can delete your cloud data at any time from Settings → Account & Data → Delete Account.

**Offline mode users:** No data is stored externally. Everything remains on your device.

---

### 5. Third-Party Services

| Service | Purpose | Data shared |
|---------|---------|-------------|
| Firebase Auth | Google Sign-In | Google UID, email |
| Firebase Firestore | Cloud sync | Transaction, category, account data |
| Firebase Crashlytics | Crash reporting | Anonymized crash stack traces |
| Google Play / App Store | App distribution, subscriptions | Managed by Google/Apple |

We do not currently use advertising SDKs. If ads are introduced in a future version, this policy will be updated and you will be notified.

---

### 6. Data Retention

- **Cloud data:** Retained until you delete your account or request deletion.
- **Local data:** Retained on your device until you uninstall the App or clear data.
- **Anonymized analytics:** Aggregated; no personal retention.

---

### 7. Your Rights

Depending on your jurisdiction, you may have the right to:

- **Access** the personal data we hold about you
- **Correct** inaccurate data
- **Delete** your data (via Settings → Account & Data, or by contacting us)
- **Export** your data (CSV/PDF export available in-app)
- **Withdraw consent** for optional data processing (e.g., revoke SMS permission, disable cloud sync)

To exercise these rights: [privacy contact email — fill at publication]

---

### 8. Children's Privacy

WLLT is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe a child under 13 has provided us with personal information, contact us immediately and we will delete it.

---

### 9. Security

We implement reasonable technical and organizational measures to protect your data:

- TLS encryption in transit
- Firebase security rules restrict data access to authenticated users only
- SMS data never leaves your device
- AI inference is fully local

No system is completely secure. We cannot guarantee absolute security.

---

### 10. Changes to This Policy

We may update this Privacy Policy. Material changes will be communicated via in-app notice or email. The "Last updated" date at the top of this page reflects the most recent revision. Continued use of the App after changes constitutes acceptance.

---

### 11. Contact

For privacy questions or data requests:  
Email: [privacy contact email — fill at publication]

---

---

# Technical Spec (for site generation)

## Stack recommendation

| Choice | Rationale |
|--------|-----------|
| Framework | Next.js (App Router) or Astro — static output, easy hosting |
| Styling | Tailwind CSS — utility-first, fast iteration |
| Animation | **GSAP** (GreenSock) — works with any framework, SSR-safe with `gsap.context()` |
| Hosting | Vercel or Netlify — free tier, custom domain, instant deploys |
| Font loading | Google Fonts (Inter) + self-hosted Archia (if licensed) |

## Mobile responsiveness

All sections must be fully responsive. Priority breakpoints:

| Breakpoint | Width |
|-----------|-------|
| Mobile | < 640px |
| Tablet | 640px – 1024px |
| Desktop | > 1024px |

Hero: two-column collapses to single column, phone mockup scales down and shifts to bottom.  
Feature sections: alternating layout collapses to vertical stack (image above text on mobile).  
Pricing cards: side-by-side collapses to vertical stack, highlighted card first.

## App Store / Play Store buttons

Use placeholder `#` hrefs until store links are live. Buttons should use official Apple/Google badge assets (SVG preferred). Wrap each in a `rel="noopener"` external link.

## GSAP Usage Guide

Use **GSAP 3** (`gsap` + `@gsap/react` for React, or plain GSAP for Astro). No ScrollTrigger plugin license needed — ScrollTrigger is included free in GSAP 3 core for non-Club members.

### Hero animation (`gsap.timeline`)

```js
const tl = gsap.timeline({ repeat: -1, repeatDelay: 3 });
tl.from(".sms-card", { x: 80, opacity: 0, duration: 0.5, ease: "power2.out" })
  .from(".arrow-line", { scaleX: 0, duration: 0.3, ease: "power1.inOut" })
  .from(".confirm-card", { y: 20, opacity: 0, duration: 0.4, ease: "back.out(1.4)" })
  .to(".check-pulse", { scale: 1.2, repeat: 1, yoyo: true, duration: 0.25 })
  .to([".sms-card", ".arrow-line", ".confirm-card"], {
    opacity: 0, duration: 0.4, delay: 2, stagger: 0.1
  });
```

### Section reveal on scroll (`ScrollTrigger`)

```js
gsap.utils.toArray(".feature-section").forEach((el) => {
  gsap.from(el, {
    scrollTrigger: { trigger: el, start: "top 80%", toggleActions: "play none none none" },
    y: 40, opacity: 0, duration: 0.7, ease: "power2.out"
  });
});
```

### Budget progress bars (animate fill on scroll-enter)

```js
gsap.utils.toArray(".budget-bar").forEach((bar) => {
  const target = bar.dataset.fill; // e.g. "0.85"
  gsap.fromTo(bar, { scaleX: 0 }, {
    scaleX: target,
    scrollTrigger: { trigger: bar, start: "top 85%" },
    duration: 1, ease: "power2.out", transformOrigin: "left center"
  });
});
```

### `prefers-reduced-motion`

```js
if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  gsap.globalTimeline.timeScale(0); // freeze all GSAP animations
}
```

All GSAP instances must be cleaned up inside `useEffect` return (React) or `document.addEventListener("astro:before-swap", ...)` (Astro view transitions).

### Compositor-only rule (performance-critical)

**Only ever animate `transform` and `opacity`.** These run on the GPU compositor thread and never trigger layout or paint.

```js
// GOOD — compositor only
gsap.to(el, { x: 40, y: -10, opacity: 0, scale: 1.05 })

// BAD — triggers layout recalculation on every frame
gsap.to(el, { left: 40, top: -10, width: "110%" })
```

Never animate: `top`, `left`, `right`, `bottom`, `width`, `height`, `margin`, `padding`, `border-width`.  
Use `x`/`y` (maps to `translateX`/`translateY`) instead of `left`/`top`.  
Use `scale` instead of `width`/`height` where visually equivalent (e.g. progress bar fill via `scaleX`).

This is not enforced by GSAP — the generator must follow it explicitly. On low-end devices, a single layout-triggering animation drops the entire page to 20–30fps.

---

## Performance targets

- LCP < 2.5s (phone mockup image must be optimized, WebP format, lazy-load below fold)
- No layout shift from font loading (use `font-display: swap` + size-adjust)
- Animations respect `prefers-reduced-motion` — disable motion when set

## SEO meta

```
Title: WLLT — Track your expenses, master your money
Description: WLLT reads your bank SMS messages, auto-logs transactions,
             and gives you AI-powered insights — all on your phone.
             Free 30-day trial.
OG image: Hero phone mockup on blush background (1200×630)
```

## Analytics

Add Google Analytics 4 or Plausible (privacy-friendly). Track:
- Page views (all three pages)
- CTA clicks (App Store, Google Play, waitlist)
- Scroll depth on landing page
