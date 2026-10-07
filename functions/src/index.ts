import { createHash, randomBytes, timingSafeEqual } from 'crypto';
import express, { Request, Response, NextFunction } from 'express';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getAppCheck } from 'firebase-admin/app-check';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { AccessToken } from 'livekit-server-sdk';
import WebSocket from 'ws';

initializeApp();

const db = getFirestore();
const PAIRING_TTL_MS = 10 * 60 * 1000;
const LIVEKIT_TTL = '10m';

const FORBIDDEN_LABELS = ['criminal', 'evil', 'malicious', 'dangerous', 'guilty'];

type AuthedRequest = Request & { uid?: string };

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function secretsMatch(candidate: string, expectedHex: string): boolean {
  const actual = Buffer.from(sha256(candidate), 'hex');
  const expected = Buffer.from(expectedHex, 'hex');
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}

async function requireUser(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.header('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) {
    res.status(401).json({ error: 'unauthenticated' });
    return;
  }
  try {
    if (process.env.ENFORCE_APP_CHECK === 'true') {
      const appCheck = req.header('x-firebase-appcheck');
      if (!appCheck) {
        res.status(401).json({ error: 'app_check_required' });
        return;
      }
      await getAppCheck().verifyToken(appCheck);
    }
    const decoded = await getAuth().verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch {
    res.status(401).json({ error: 'unauthenticated' });
  }
}

async function requireRole(orgId: string, uid: string, roles: string[]) {
  const member = await db.doc(`organizations/${orgId}/members/${uid}`).get();
  const role = member.data()?.role as string | undefined;
  if (!role || !roles.includes(role)) {
    const error = new Error('forbidden');
    (error as Error & { status: number }).status = 403;
    throw error;
  }
  return role;
}

const buckets = new Map<string, { tokens: number; updated: number }>();

function takeToken(key: string, capacity: number, perSecond: number): boolean {
  const now = Date.now();
  const bucket = buckets.get(key) ?? { tokens: capacity, updated: now };
  const elapsed = (now - bucket.updated) / 1000;
  bucket.tokens = Math.min(capacity, bucket.tokens + elapsed * perSecond);
  bucket.updated = now;
  if (bucket.tokens < 1) {
    buckets.set(key, bucket);
    return false;
  }
  bucket.tokens -= 1;
  buckets.set(key, bucket);
  return true;
}

const app = express();
app.use(express.json({ limit: '4mb' }));
app.use(requireUser);

app.post('/v1/pairing-tokens', async (req: AuthedRequest, res: Response) => {
  const orgId = String(req.body.organizationId ?? '');
  if (!orgId) {
    res.status(400).json({ error: 'organization_required' });
    return;
  }
  if (!takeToken(`pair:${req.uid}`, 5, 5 / 60)) {
    res.status(429).json({ error: 'rate_limited' });
    return;
  }
  await requireRole(orgId, req.uid!, ['owner', 'admin']);
  const secret = randomBytes(32).toString('base64url');
  const tokenRef = db.collection(`organizations/${orgId}/pairingTokens`).doc();
  const expiresAt = Timestamp.fromMillis(Date.now() + PAIRING_TTL_MS);
  await tokenRef.set({
    organizationId: orgId,
    secretHash: sha256(secret),
    createdBy: req.uid,
    createdAt: Timestamp.now(),
    expiresAt,
    consumedAt: null,
    consumedByDeviceId: null,
  });
  res.json({
    tokenId: tokenRef.id,
    organizationId: orgId,
    secret,
    expiresAt: expiresAt.toDate().toISOString(),
  });
});

app.post('/v1/pairing-tokens/claim', async (req: AuthedRequest, res: Response) => {
  const orgId = String(req.body.organizationId ?? '');
  const tokenId = String(req.body.tokenId ?? '');
  const secret = String(req.body.secret ?? '');
  const deviceId = String(req.body.deviceId ?? '');
  const name = String(req.body.name ?? 'Camera').slice(0, 60);
  const location = String(req.body.location ?? '').slice(0, 80);
  if (!orgId || !tokenId || !secret || !deviceId) {
    res.status(400).json({ error: 'invalid_claim' });
    return;
  }
  const ref = db.doc(`organizations/${orgId}/pairingTokens/${tokenId}`);
  const cameraRef = db.collection(`organizations/${orgId}/cameras`).doc();
  const cameraId = cameraRef.id;
  const memberRef = db.doc(`organizations/${orgId}/members/${req.uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const member = await tx.get(memberRef);
    const data = snap.data();
    if (!data) throw Object.assign(new Error('unknown_token'), { status: 404 });
    if (data.consumedAt) throw Object.assign(new Error('token_used'), { status: 409 });
    if (data.expiresAt.toDate().getTime() < Date.now()) {
      throw Object.assign(new Error('token_expired'), { status: 410 });
    }
    if (!secretsMatch(secret, data.secretHash)) {
      throw Object.assign(new Error('token_rejected'), { status: 403 });
    }
    tx.update(ref, {
      consumedAt: Timestamp.now(),
      consumedByDeviceId: deviceId,
    });
    tx.set(cameraRef, {
      id: cameraId,
      organizationId: orgId,
      name,
      location,
      operatorUserId: req.uid,
      deviceId,
      createdAt: Timestamp.now(),
      monitoring: false,
      heartbeat: {
        operationalState: 'idle',
        aiStatus: 'idle',
        monitoredAt: Timestamp.now(),
        batteryPercent: null,
        charging: false,
        peopleCount: 0,
        riskLevel: 'normal',
        riskScore: 0,
        activity: '',
        networkQuality: 'unknown',
      },
    });
    if (!member.exists) {
      tx.set(memberRef, {
        userId: req.uid,
        role: 'securityOperator',
        createdAt: Timestamp.now(),
      });
    }
  });
  res.json({ cameraId, organizationId: orgId });
});

app.post('/v1/livekit/token', async (req: AuthedRequest, res: Response) => {
  const orgId = String(req.body.organizationId ?? '');
  const cameraId = String(req.body.cameraId ?? '');
  const role = req.body.role === 'publisher' ? 'publisher' : 'subscriber';
  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;
  const url = process.env.LIVEKIT_URL;
  if (!apiKey || !apiSecret || !url) {
    res.status(503).json({ error: 'livekit_unconfigured' });
    return;
  }
  if (!takeToken(`live:${req.uid}`, 20, 20 / 60)) {
    res.status(429).json({ error: 'rate_limited' });
    return;
  }
  await requireRole(orgId, req.uid!, ['owner', 'admin', 'securityOperator', 'viewer']);
  if (role === 'publisher') {
    const camera = await db.doc(`organizations/${orgId}/cameras/${cameraId}`).get();
    if (camera.data()?.operatorUserId !== req.uid) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }
  }
  const room = `org_${orgId}_cam_${cameraId}`;
  const token = new AccessToken(apiKey, apiSecret, {
    identity: `${role}_${req.uid}_${cameraId}`,
    ttl: LIVEKIT_TTL,
  });
  token.addGrant({
    roomJoin: true,
    room,
    canPublish: role === 'publisher',
    canSubscribe: true,
  });
  res.json({ url, room, token: await token.toJwt(), role });
});

const liveSessions = new Map<string, WebSocket>();

function geminiSetup(): string {
  const model = process.env.GEMINI_LIVE_MODEL || 'gemini-3.8-live';
  return JSON.stringify({
    setup: {
      model: `models/${model}`,
      generationConfig: {
        responseModalities: ['TEXT'],
        temperature: 0.2,
        maxOutputTokens: 800,
      },
      systemInstruction: {
        parts: [{
          text: [
            'You are a security-camera scene interpreter.',
            'Describe only observable behavior.',
            'Never call a person criminal, evil, malicious, dangerous, or guilty.',
            'Reply with one JSON object and no markdown.',
            'Keys: scene_state, people_count, activity, description, risk_score, risk_level, suspicious, preserve_recording, notify_owner, request_human_review, observations, uncertainties.',
            'risk_level is one of normal, low, medium, high, critical.',
            'risk_score is an integer from 0 to 100.',
          ].join(' '),
        }],
      },
    },
  });
}

async function ensureGemini(sessionKey: string): Promise<WebSocket> {
  const existing = liveSessions.get(sessionKey);
  if (existing && existing.readyState === WebSocket.OPEN) return existing;
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw Object.assign(new Error('gemini_unconfigured'), { status: 503 });
  const url = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=${apiKey}`;
  const socket = await new Promise<WebSocket>((resolve, reject) => {
    const ws = new WebSocket(url);
    const timeout = setTimeout(() => {
      ws.close();
      reject(Object.assign(new Error('gemini_timeout'), { status: 504 }));
    }, 10000);
    ws.once('open', () => {
      ws.send(geminiSetup());
    });
    ws.on('message', (raw) => {
      const message = JSON.parse(raw.toString());
      if (message.setupComplete) {
        clearTimeout(timeout);
        resolve(ws);
      }
    });
    ws.once('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });
  liveSessions.set(sessionKey, socket);
  socket.on('close', () => {
    if (liveSessions.get(sessionKey) === socket) liveSessions.delete(sessionKey);
  });
  return socket;
}

function extractText(message: Record<string, unknown>): string {
  const server = message.serverContent as { modelTurn?: { parts?: Array<{ text?: string }> } } | undefined;
  const parts = server?.modelTurn?.parts ?? [];
  return parts.map((part) => part.text ?? '').join('');
}

app.post('/v1/ai/frames', async (req: AuthedRequest, res: Response) => {
  const orgId = String(req.body.organizationId ?? '');
  const cameraId = String(req.body.cameraId ?? '');
  const jpegBase64 = String(req.body.jpegBase64 ?? '');
  const sceneState = req.body.sceneState ?? {};
  if (!orgId || !cameraId || !jpegBase64) {
    res.status(400).json({ error: 'invalid_frame' });
    return;
  }
  if (!takeToken(`ai:${orgId}:${cameraId}`, 8, 2)) {
    res.status(429).json({ error: 'rate_limited' });
    return;
  }
  const camera = await db.doc(`organizations/${orgId}/cameras/${cameraId}`).get();
  if (!camera.exists || camera.data()?.operatorUserId !== req.uid) {
    res.status(403).json({ error: 'forbidden' });
    return;
  }
  const socket = await ensureGemini(`${orgId}:${cameraId}`);
  const update = await new Promise<string>((resolve, reject) => {
    let buffer = '';
    const timeout = setTimeout(() => {
      socket.off('message', onMessage);
      reject(Object.assign(new Error('gemini_timeout'), { status: 504 }));
    }, 12000);
    const onMessage = (raw: WebSocket.RawData) => {
      const message = JSON.parse(raw.toString()) as Record<string, unknown>;
      buffer += extractText(message);
      const server = message.serverContent as { turnComplete?: boolean } | undefined;
      if (server?.turnComplete) {
        clearTimeout(timeout);
        socket.off('message', onMessage);
        resolve(buffer);
      }
    };
    socket.on('message', onMessage);
    socket.send(JSON.stringify({
      realtimeInput: { video: { data: jpegBase64, mimeType: 'image/jpeg' } },
    }));
    socket.send(JSON.stringify({
      clientContent: {
        turns: [{
          role: 'user',
          parts: [{
            text: `Update the scene. Previous compact state: ${JSON.stringify(sceneState)}. Context: ${JSON.stringify(req.body.context ?? {})}`,
          }],
        }],
        turnComplete: true,
      },
    }));
  });
  const parsed = parseGeminiJson(update);
  res.json(parsed);
});

function parseGeminiJson(raw: string): Record<string, unknown> {
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start < 0 || end < start) {
    throw Object.assign(new Error('gemini_unstructured'), { status: 502 });
  }
  const value = JSON.parse(raw.slice(start, end + 1)) as Record<string, unknown>;
  const description = String(value.description ?? '');
  const lowered = description.toLowerCase();
  if (FORBIDDEN_LABELS.some((word) => lowered.includes(word))) {
    value.description = 'Activity needs human review.';
    value.uncertainties = [
      ...((value.uncertainties as unknown[]) ?? []),
      'Description omitted a disallowed judgement.',
    ];
  }
  return value;
}

app.use((error: Error & { status?: number }, _req: Request, res: Response, _next: NextFunction) => {
  const status = error.status ?? 500;
  res.status(status).json({ error: error.message || 'internal' });
});

export const api = onRequest({ cors: true, timeoutSeconds: 60, memory: '512MiB' }, app);

export const onIncidentCreated = onDocumentCreated(
  'organizations/{orgId}/incidents/{incidentId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const level = String(data.riskLevel ?? '');
    if (level !== 'high' && level !== 'critical') return;
    const orgId = event.params.orgId;
    const members = await db.collection(`organizations/${orgId}/members`).get();
    const tokens: string[] = [];
    for (const member of members.docs) {
      const role = member.data().role as string;
      if (!['owner', 'admin', 'securityOperator'].includes(role)) continue;
      const user = await db.doc(`users/${member.id}`).get();
      const registered = user.data()?.fcmTokens;
      if (Array.isArray(registered)) {
        tokens.push(...registered.map((token) => String(token)));
      }
    }
    if (tokens.length == 0) return;
    const { getMessaging } = await import('firebase-admin/messaging');
    await getMessaging().sendEachForMulticast({
      tokens: [...new Set(tokens)],
      notification: {
        title: `${level.toUpperCase()} SECURITY ALERT`,
        body: `${data.cameraName ?? 'Camera'}: ${data.description ?? 'Review this incident.'}`,
      },
      data: {
        incidentId: event.params.incidentId,
        organizationId: orgId,
        route: 'incident',
      },
    });
  },
);
