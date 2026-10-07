/**
 * The legal pages (roadmap F7): Terms of Service, Privacy Policy (with the
 * data-retention policy) and Acceptable Use Policy.
 *
 * DRAFTS. They describe what the service actually does, as built, but have
 * not been reviewed by a lawyer. Before launch: fill in every [PLACEHOLDER],
 * have them reviewed for the countries you sell in, and set UPDATED.
 *
 * Each document is a list of sections; each section a heading and paragraphs
 * (a paragraph that is an array renders as a bullet list).
 */
export const COMPANY = '[COMPANY LEGAL NAME]'
export const CONTACT = '[CONTACT EMAIL]'
export const UPDATED = '[DATE]'

const terms = {
  title: 'Terms of Service',
  sections: [
    {
      heading: 'About these terms',
      body: [
        `These terms are an agreement between you and ${COMPANY} (“we”) for using CognitiveAI Bot: the website, the mobile and desktop apps, and the developer API (together, “the service”). By creating an account or using the service you accept them. If you use it for an organisation, you accept them for that organisation.`,
      ],
    },
    {
      heading: 'Your account',
      body: [
        'You must be at least [18] years old, give a real email address and keep your password and API keys safe. You are responsible for what happens through your account and keys. Tell us at once if you think someone else is using them.',
        'Some features need a confirmed email address, including buying credits and creating API keys.',
      ],
    },
    {
      heading: 'What the service does',
      body: [
        'The service sends your requests to AI models made by other companies (such as OpenAI, Anthropic and Google) and returns their answers. Each model is called directly at the company that makes it. AI output can be wrong, incomplete or offensive; check it before relying on it, and don’t use it as professional (medical, legal, financial) advice.',
      ],
    },
    {
      heading: 'Credits, plans and payment',
      body: [
        'Using a model costs credits. Each model has a published price in credits, and a request is charged for what it actually used, as reported by the model’s maker. A reply may be shortened if your balance can’t cover a longer one.',
        [
          'Plans are subscriptions that renew automatically until cancelled. Each paid period grants that period’s credits; unused plan credits expire at the end of the period.',
          'Top-up credits don’t expire while your account exists.',
          'Credits have no cash value and can’t be transferred or exchanged for money.',
          'You can cancel a web subscription at any time from Manage billing; it ends at the end of the paid period. App Store subscriptions are managed and refunded by Apple under its terms.',
          `Payments are refunded only where the law requires it or at our discretion. If a payment is refunded or reversed, the credits it bought are removed. Contact ${CONTACT} about billing problems.`,
        ],
        'We may change prices and plans. A price change applies to new purchases and, for a running subscription, from its next renewal after we give notice.',
      ],
    },
    {
      heading: 'The developer API',
      body: [
        'API access comes with plans that include it, within that plan’s rate limits. Don’t share keys, resell access or use the API to build a competing service that simply resells the same models, unless we agree in writing.',
      ],
    },
    {
      heading: 'Acceptable use',
      body: [
        'You must follow the Acceptable Use Policy and the usage policies of the model makers whose models you use. We check prompts for prohibited content, may refuse requests, and may suspend or close accounts that break these rules.',
      ],
    },
    {
      heading: 'Your content',
      body: [
        'You keep your rights in what you send (prompts, files) and, as far as the law and the model makers’ terms allow, in what the models return for you. You give us permission to process your content only to provide the service. We don’t use your content to train AI models.',
      ],
    },
    {
      heading: 'Suspension and ending',
      body: [
        'You can delete your account at any time from your profile. We may suspend or close an account that breaks these terms, harms others or the service, or is used for fraud; where reasonable we will tell you why. Credits left in a closed account are lost unless the law requires otherwise.',
      ],
    },
    {
      heading: 'Disclaimers and liability',
      body: [
        'The service is provided “as is”. We don’t promise it will be uninterrupted or error-free, or that any model will stay available. To the extent the law allows, our total liability to you is limited to the amount you paid us in the 12 months before the claim, and we aren’t liable for indirect or consequential losses. Nothing here limits liability that can’t legally be limited.',
      ],
    },
    {
      heading: 'Changes and law',
      body: [
        'We may update these terms; we will notify you of material changes before they apply. These terms are governed by the laws of [JURISDICTION], and disputes go to the courts of [VENUE], unless your local consumer law says otherwise.',
        `Questions: ${CONTACT}.`,
      ],
    },
  ],
}

const privacy = {
  title: 'Privacy Policy',
  sections: [
    {
      heading: 'Who we are',
      body: [`${COMPANY}, [ADDRESS], runs CognitiveAI Bot and is responsible for your personal data. Contact: ${CONTACT}.`],
    },
    {
      heading: 'What we collect',
      body: [
        [
          'Account: your email, name, password (stored only as a one-way hash), profile picture, and whether you confirmed your email. If you sign in with Google or GitHub, the identifier they give us.',
          'Chats in the apps: your conversations, so you can see your history. You can delete any chat, or your whole account.',
          'Settings: your preferences, including any custom instructions.',
          'Billing: your plan, subscription status, credit balance and transactions. Card details are handled by Stripe (web) or Apple (App Store); we never see your card number.',
          'Usage records: for every request, the time, model, amount used (tokens, characters or seconds), cost and outcome. These are what we bill from.',
          'Technical data: IP addresses for security limits (for example, how many sign-ups come from one network), and error logs.',
        ],
      ],
    },
    {
      heading: 'What we don’t keep',
      body: [
        'Prompts and replies sent through the developer API are not stored; only the usage record above is kept. The one exception is a generated video, kept for 7 days so it can be downloaded. Images, audio and transcripts made through the API are returned to you and not kept.',
      ],
    },
    {
      heading: 'Who receives your data',
      body: [
        [
          'The maker of the AI model you choose (for example OpenAI, Anthropic or Google) receives your prompt to answer it, under its own terms. Prompts are also checked with OpenAI’s moderation model.',
          'Stripe and Apple (through RevenueCat) process payments.',
          'Our email provider sends account emails such as password resets.',
          'Our hosting and database providers store the data above: [HOSTING PROVIDER, REGION].',
        ],
        'We don’t sell personal data and don’t use your content to train models. We share data with authorities only when the law requires it.',
      ],
    },
    {
      heading: 'How long we keep it (data retention)',
      body: [
        [
          'Account, chats and settings: until you delete them or your account.',
          'Generated videos: 7 days, then deleted.',
          'Password reset and email confirmation links: expire after 1 hour and 24 hours.',
          'Usage records and billing transactions: kept after account deletion, without your name or email, for [7] years for accounting and tax law.',
          'Content reports you send: until reviewed and for [1 year] after, to handle disputes.',
        ],
      ],
    },
    {
      heading: 'Your rights',
      body: [
        'You can download all the data we hold about you, and delete your account, from your profile. Deleting your account erases your chats, settings, keys and profile at once and cancels any web subscription. Depending on where you live you may also have rights to correct, restrict or object to processing, and to complain to your data protection authority. Contact us to use them.',
      ],
    },
    {
      heading: 'Legal bases (EU/UK)',
      body: [
        'We process data to provide the service you asked for (contract), to keep it secure and prevent fraud (legitimate interest), and to meet accounting and tax law (legal obligation).',
      ],
    },
    {
      heading: 'Security and storage',
      body: [
        'Passwords and API keys are stored only as one-way hashes. Data is sent over encrypted connections. Your data may be processed in countries other than yours, including by the model makers; where required we rely on standard contractual clauses. [CONFIRM PROVIDER DATA LOCATIONS.]',
      ],
    },
    {
      heading: 'Children',
      body: ['The service isn’t for anyone under [18]. We delete accounts we learn belong to one.'],
    },
    {
      heading: 'Cookies and storage',
      body: [
        'We don’t use advertising or tracking cookies. The website keeps your sign-in session in your browser’s local storage; signing out removes it.',
      ],
    },
  ],
}

const acceptableUse = {
  title: 'Acceptable Use Policy',
  sections: [
    {
      heading: 'The short version',
      body: ['Use CognitiveAI Bot lawfully and don’t use it to hurt people. The model makers’ own usage policies also apply to their models.'],
    },
    {
      heading: 'You must not use the service to',
      body: [
        [
          'Create or seek sexual content involving minors. We block it, report it to admins, and report it to the authorities where the law requires.',
          'Create sexual or graphically violent images or video, or images of real people without their consent.',
          'Harass, threaten, defame or incite violence or hatred against people or groups.',
          'Plan or carry out violence, terrorism, or weapons capable of mass harm.',
          'Commit fraud, scams, phishing or impersonation, or create malware or break into systems you don’t own.',
          'Infringe others’ intellectual property or privacy, or collect personal data without a lawful basis.',
          'Make decisions with legal or similarly significant effects on people (credit, housing, employment, insurance, legal status) without human review.',
          'Get around safety measures, rate limits or billing, share accounts or keys, or overload the service.',
        ],
      ],
    },
    {
      heading: 'How we enforce it',
      body: [
        'Prompts are checked automatically before they reach a model, and image and video prompts more strictly. Users can report replies. Breaking this policy can lead to refused requests, suspension or closure of the account, and reports to the authorities.',
        `Report abuse: ${CONTACT}.`,
      ],
    },
  ],
}

export const DOCUMENTS = { terms, privacy, 'acceptable-use': acceptableUse }
