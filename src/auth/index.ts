import passport from 'passport';
import { Strategy as GoogleStrategy, Profile } from 'passport-google-oauth20';
import { Request, Response, NextFunction } from 'express';
import { Config } from '../types';
import { DatabaseService } from '../database';

export interface AuthUser {
  email: string;
  googleId: string;
  name: string;
  picture?: string;
}

export class AuthService {
  private config: Config;
  private db: DatabaseService;
  private authorizedEmails: Set<string>;

  constructor(config: Config, db: DatabaseService) {
    this.config = config;
    this.db = db;
    this.authorizedEmails = new Set();

    // Load authorized users from config if provided
    this.loadAuthorizedUsers();

    // Setup passport
    this.setupPassport();
  }

  private loadAuthorizedUsers(): void {
  console.log('🔍 Loading authorized users...');

  const norm = (s: string) => s.trim().toLowerCase();

  // ENV seed
  const envUsers = (process.env.AUTHORIZED_GOOGLE_USERS ?? '')
    .split(',')
    .map(s => norm(s))
    .filter(Boolean);

  if (envUsers.length) {
    console.log('ENV authorized users:', envUsers);
    envUsers.forEach(e => { this.authorizedEmails.add(e); this.db.addAuthorizedUser(e); });
  }

  // YAML / Config (support both snake_case and camelCase)
  const cfgUsersSnake = (this.config as any).authorized_google_users as string[] | undefined;
  const cfgUsersCamel = (this.config as any).authorizedGoogleUsers as string[] | undefined;
  const cfgUsers = (cfgUsersSnake ?? cfgUsersCamel ?? []).map(norm).filter(Boolean);

  if (cfgUsers.length) {
    console.log('Config authorized users:', cfgUsers);
    cfgUsers.forEach(e => { this.authorizedEmails.add(e); this.db.addAuthorizedUser(e); });
  } else {
    console.log('No authorized users found in config');
  }

  // DB (if synchronous)
  try {
    const dbUsers = this.db.getAuthorizedUsers?.() ?? [];
    console.log('Users from database:', dbUsers);
    dbUsers.forEach((u: any) => {
      if (u?.google_email) this.authorizedEmails.add(norm(u.google_email));
    });
  } catch (e) {
    console.warn('Skipping DB authorized users (error):', e);
  }

  const finalList = Array.from(this.authorizedEmails);
  console.log('Final authorized emails:', finalList);

  // Fail fast if you expect *someone* to be allowed
  if (!finalList.length && process.env.FAIL_IF_NO_AUTHORIZED === '1') {
    throw new Error('No authorized users loaded (ENV/config/DB all empty).');
  }
}


  private setupPassport(): void {
    const clientId = process.env.GOOGLE_MEET_CLIENT_ID || process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_MEET_CLIENT_SECRET || process.env.GOOGLE_CLIENT_SECRET;
    const callbackUrl = process.env.GOOGLE_AUTH_CALLBACK_URL || 'http://localhost:3000/auth/google/callback';

    if (!clientId || !clientSecret) {
      console.warn('⚠️  Google OAuth credentials not configured. Authentication will be disabled.');
      return;
    }

    passport.use(new GoogleStrategy({
      clientID: clientId,
      clientSecret: clientSecret,
      callbackURL: callbackUrl,
      scope: ['profile', 'email']
    }, async (accessToken, refreshToken, profile: Profile, done) => {
      try {
        const email = profile.emails?.[0]?.value?.toLowerCase();

        if (!email) {
          return done(new Error('No email found in Google profile'));
        }

        // Check if user is authorized
        if (!this.isAuthorizedUser(email)) {
          return done(new Error(`Unauthorized user: ${email}`));
        }

        // Update user in database
        this.db.updateUserLogin(
          email,
          profile.id,
          profile.displayName,
          profile.photos?.[0]?.value
        );

        const user: AuthUser = {
          email,
          googleId: profile.id,
          name: profile.displayName,
          picture: profile.photos?.[0]?.value
        };

        return done(null, user);
      } catch (error) {
        return done(error as Error);
      }
    }) as any);

    passport.serializeUser((user: any, done) => {
      done(null, user.email);
    });

    passport.deserializeUser(async (email: string, done) => {
      try {
        const users = this.db.getAuthorizedUsers();
        const user = users.find(u => u.google_email === email);

        if (user) {
          const authUser: AuthUser = {
            email: user.google_email,
            googleId: user.google_id || '',
            name: user.name || '',
            picture: user.picture
          };
          done(null, authUser);
        } else {
          done(null, false);
        }
      } catch (error) {
        done(error);
      }
    });
  }

  isAuthorizedUser(email: string): boolean {
    return this.authorizedEmails.has(email.toLowerCase()) || this.db.isUserAuthorized(email.toLowerCase());
  }

  addAuthorizedUser(email: string): void {
    const normalizedEmail = email.toLowerCase();
    this.authorizedEmails.add(normalizedEmail);
    this.db.addAuthorizedUser(normalizedEmail);
  }

  removeAuthorizedUser(email: string): void {
    const normalizedEmail = email.toLowerCase();
    this.authorizedEmails.delete(normalizedEmail);
    this.db.removeAuthorizedUser(normalizedEmail);
  }

  getAuthorizedUsers(): string[] {
    return Array.from(this.authorizedEmails);
  }

  // Middleware for protecting routes
  requireAuth(req: Request, res: Response, next: NextFunction): void {
    if (!req.isAuthenticated()) {
      const acceptHeader = req.headers.accept || '';
      if (req.xhr || acceptHeader.indexOf('json') > -1) {
        res.status(401).json({ error: 'Authentication required' });
      } else {
        res.redirect('/auth/login');
      }
    } else {
      next();
    }
  }

  // Middleware for optional auth (sets user if logged in, but doesn't require it)
  optionalAuth(req: Request, res: Response, next: NextFunction): void {
    next();
  }

  // Get current user from request
  getCurrentUser(req: Request): AuthUser | null {
    return req.user as AuthUser || null;
  }
}
