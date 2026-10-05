/// Fixed wording for backend error codes the app explains in its own words.
/// Anything else shows the server's own message.
const _messages = {
  'CONTENT_BLOCKED': 'This request breaks the content rules, so it wasn’t sent.',
  'TOO_MANY_MESSAGES': 'You’re sending messages very fast. Wait a moment, then try again.',
  'EMAIL_NOT_VERIFIED': 'Confirm your email to get your trial credits and to buy credits.',
};

/// The text to show for a failure with [code], falling back to [serverMessage].
String errorMessageFor(String? code, String? serverMessage, {String fallback = 'Something went wrong. Try again.'}) =>
    _messages[code] ?? serverMessage ?? fallback;
