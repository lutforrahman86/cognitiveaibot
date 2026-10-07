# Provider terms review (roadmap F7)

**Status: first pass, not legal advice.** Read on 2026-10-05 from each
provider's published terms. Have a lawyer confirm before launch, and repeat
this review when a provider is added or changes its terms.

We offer models in two ways, and the terms treat them differently:

- **The apps** (web, mobile, desktop chat): our own product, built on each
  provider's API. This is the ordinary, permitted use for all three providers.
- **The developer API** (`/v1`): paying customers call the models through us.
  To a provider this can look like **reselling access**, which is where the
  risk is.

## Summary

| Provider | Apps | Developer API | Action |
|---|---|---|---|
| Anthropic | Allowed | **Prohibited without express approval** | Ask Anthropic for approval, or remove Claude models from `/v1` until approved |
| OpenAI | Allowed | **Unclear**: account resale is prohibited; integrating the API into our own product is allowed | Confirm with OpenAI (sales or support) that `/v1` is a permitted "Customer Application" |
| Google (Gemini) | Allowed, on a **paid** tier for EEA/UK/Swiss users | Allowed as far as read; no competing models | Make sure the Gemini key's project has billing enabled (paid tier); set the minimum user age to 18 |

## Anthropic: Commercial Terms of Service (effective 17 June 2025)

Source: <https://www.anthropic.com/legal/commercial-terms>

- **Section D.4:** customers may not access the services "to build a competing
  product or service, including to train competing AI models or resell the
  Services", except with Anthropic's express approval. A pass-through API that
  sells Claude access to third parties most likely falls under "resell".
- **A.1, D.2, D.3:** we're responsible for our users following Anthropic's
  Usage Policy, and must tell users that factual statements in outputs should be
  checked independently. (The Terms and the chat should say so; the draft Terms
  do.)
- **Section B:** Anthropic doesn't train on our customers' content; we own the outputs.

**Recommendation:** write to Anthropic (sales) describing the developer API
and asking for approval. Until it's granted, take Claude models off `/v1`
(the chat apps can keep them). That's a per-model switch I can add.

## OpenAI: Services Agreement (current version dated January 2026)

Sources: <https://openai.com/policies/services-agreement/> (the page blocks
automated reading; the clauses below come from openai.com search results and
need checking against the full text), <https://openai.com/policies/service-terms/>

- The customer "may not resell or lease access to its Account or any End User
  Account", nor share credentials between users.
- The customer may "integrate the Services into Customer Applications and …
  make Customer Applications available to End Users", where a Customer
  Application is the customer's own product or service that integrates an
  OpenAI API.
- The customer must not let end users break the law or OpenAI's policies.

**Reading:** the chat apps are clearly Customer Applications. `/v1` is our own
product with its own keys, billing and moderation, and doesn't hand out OpenAI
accounts, so it is arguably a Customer Application too. But it closely
resembles reselling API access. **Get written confirmation from OpenAI** before
selling API plans that include OpenAI models.

## Google: Gemini API Additional Terms (effective 23 March 2026)

Source: <https://ai.google.dev/gemini-api/terms>

- No developing models that compete with Google's, and no reverse engineering.
- **Paid vs unpaid:** on unpaid (free-tier) use, Google may use prompts and
  responses to improve its products, with human review. On paid services it
  doesn't. We must be on a **paid tier**: our privacy policy says providers
  don't train on users' content.
- **EEA, Switzerland and the UK:** apps made available to users there may use
  only paid services.
- **Minimum age 18.** The draft Terms now say 18 (the strictest of the three).
- We're responsible for appropriate safety settings for our use case.

## Not reviewed yet

The other providers in the catalog (DeepSeek, Mistral, xAI, Perplexity, Qwen,
Moonshot, Z.ai, MiniMax, and Meta if it's ever connected) have no direct
integration yet. Review each one's terms, for resale and for where data is
processed, before connecting it.
