const passport = require('passport');
const LocalStrategy = require('passport-local').Strategy;
const GoogleStrategy = require('passport-google-oauth20').Strategy;
const GitHubStrategy = require('passport-github2').Strategy;
const bcrypt = require('bcrypt');
const User = require('../models/User');

const frontendUrl = process.env.FRONTEND_URL || 'http://localhost:5173';

// Local strategy for email/password authentication
passport.use(
  new LocalStrategy(
    {
      usernameField: 'email',
      passwordField: 'password',
      passReqToCallback: false,
    },
    async (email, password, done) => {
      try {
        if (!email || !password) {
          return done(null, false, { message: 'Email and password are required' });
        }
        const user = await User.findOne({
          where: { email: email.trim().toLowerCase() },
          attributes: ['id', 'email', 'password_hash', 'name', 'type', 'created_at', 'suspended_at', 'email_verified_at'],
        });
        if (!user) {
          return done(null, false, { message: 'Invalid email or password' });
        }
        const userPlain = user.get({ plain: true });
        if (!userPlain.password_hash) {
          return done(null, false, { message: 'This account uses Google or GitHub sign-in' });
        }
        const valid = await bcrypt.compare(password, userPlain.password_hash);
        if (!valid) {
          return done(null, false, { message: 'Invalid email or password' });
        }
        if (userPlain.suspended_at) {
          return done(null, false, { message: 'This account is suspended. Contact support.' });
        }
        return done(null, {
          id: userPlain.id,
          email: userPlain.email,
          name: userPlain.name,
          type: userPlain.type || 'user',
          created_at: userPlain.created_at,
          email_verified_at: userPlain.email_verified_at,
        });
      } catch (err) {
        return done(err, null);
      }
    }
  )
);

function getCallbackUrl(provider) {
  const base = process.env.API_URL || `http://localhost:${process.env.PORT || 3000}`;
  return `${base}/api/auth/${provider}/callback`;
}

if (process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET) {
  passport.use(
    new GoogleStrategy(
      {
        clientID: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
        callbackURL: getCallbackUrl('google'),
        scope: ['profile', 'email'],
      },
      async (accessToken, refreshToken, profile, done) => {
        try {
          const email = profile.emails?.[0]?.value?.toLowerCase();
          const name = profile.displayName || profile.name?.givenName;
          const googleId = profile.id;

          let u = await User.findOne({ where: { google_id: googleId } });

          if (u) {
            return done(null, { ...u.get({ plain: true }), type: u.type || 'user' });
          }

          if (email) {
            u = await User.findOne({ where: { email } });
            if (u) {
              // The provider has verified this email. If the existing account
              // never verified it, someone else may have registered it: drop its
              // password so only the provider sign-in gets in.
              await u.update({
                google_id: googleId,
                ...(u.email_verified_at ? {} : { password_hash: null, email_verified_at: new Date(), password_changed_at: new Date() }),
              });
              return done(null, { ...u.get({ plain: true }), type: u.type || 'user' });
            }
          }

          if (!email) {
            return done(new Error('Email is required. Please grant email permission to sign in with Google.'), null);
          }
          u = await User.create({
            email,
            password_hash: null,
            name: name || null,
            google_id: googleId,
            email_verified_at: new Date(),
          });
          await require('../auth/accounts').grantTrialCredits(u.id);
          return done(null, { ...u.get({ plain: true }), type: u.type || 'user' });
        } catch (err) {
          return done(err, null);
        }
      }
    )
  );
}

if (process.env.GITHUB_CLIENT_ID && process.env.GITHUB_CLIENT_SECRET) {
  passport.use(
    new GitHubStrategy(
      {
        clientID: process.env.GITHUB_CLIENT_ID,
        clientSecret: process.env.GITHUB_CLIENT_SECRET,
        callbackURL: getCallbackUrl('github'),
        scope: ['user:email'],
      },
      async (accessToken, refreshToken, profile, done) => {
        try {
          const email = profile.emails?.[0]?.value?.toLowerCase();
          const name = profile.displayName || profile.username;
          const githubId = profile.id;

          let u = await User.findOne({ where: { github_id: githubId } });

          if (u) {
            return done(null, { ...u.get({ plain: true }), type: u.type || 'user' });
          }

          if (email) {
            u = await User.findOne({ where: { email } });
            if (u) {
              // The provider has verified this email. If the existing account
              // never verified it, someone else may have registered it: drop its
              // password so only the provider sign-in gets in.
              await u.update({
                github_id: githubId,
                ...(u.email_verified_at ? {} : { password_hash: null, email_verified_at: new Date(), password_changed_at: new Date() }),
              });
              return done(null, { ...u.get({ plain: true }), type: u.type || 'user' });
            }
          }

          if (!email) {
            return done(new Error('Email is required. Please add a public email to your GitHub account or grant email permission.'), null);
          }
          u = await User.create({
            email,
            password_hash: null,
            name: name || null,
            github_id: githubId,
            email_verified_at: new Date(),
          });
          await require('../auth/accounts').grantTrialCredits(u.id);
          return done(null, { ...u.get({ plain: true }), type: u.type || 'user' });
        } catch (err) {
          return done(err, null);
        }
      }
    )
  );
}

module.exports = { passport, frontendUrl };
