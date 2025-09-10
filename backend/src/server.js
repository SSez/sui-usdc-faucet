import { config as dotenvConfig } from "dotenv";
import { fileURLToPath } from "url";
import path from "path";
import express from "express";
import cors from "cors";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { decodeSuiPrivateKey } from "@mysten/sui/cryptography";
import { bech32 } from "bech32";

// Load .env explicitly from backend/.env regardless of cwd
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenvConfig({ path: path.join(__dirname, "..", ".env") });

const app = express();
app.use(express.json());
app.use(
  cors({
    origin: ["http://localhost:3000"],
    methods: ["POST", "OPTIONS"],
  })
);

// Env
const PORT = Number(process.env.PORT || 8787);
const FULLNODE_URL =
  process.env.FULLNODE_URL || "https://fullnode.devnet.sui.io:443";
const FAUCET_ID = process.env.FAUCET_ID || "";
const CLOCK = process.env.CLOCK || "0x6";
const PRIVATE_KEY_HEX = process.env.SUI_PRIVATE_KEY || "";
// Circle stablecoin path (generic faucet in stablecoin package)
const STABLECOIN_PACKAGE = process.env.STABLECOIN_PACKAGE || "";
const USDC_PACKAGE = process.env.USDC_PACKAGE || "";
const TREASURY = process.env.TREASURY || ""; // stablecoin::treasury::Treasury<USDC>

// Diagnose missing envs explicitly (without printing secrets)
const isStablecoinMode = !!(STABLECOIN_PACKAGE && USDC_PACKAGE && TREASURY && FAUCET_ID);

const _missing = [
  !FAUCET_ID && "FAUCET_ID",
  !STABLECOIN_PACKAGE && "STABLECOIN_PACKAGE",
  !USDC_PACKAGE && "USDC_PACKAGE",
  !TREASURY && "TREASURY",
  !PRIVATE_KEY_HEX && "SUI_PRIVATE_KEY",
].filter(Boolean);
if (_missing.length) {
  // eslint-disable-next-line no-console
  console.warn(`Missing env: ${_missing.join(", ")}`);
  // eslint-disable-next-line no-console
  console.warn(
    `cwd=${process.cwd()} FULLNODE_URL=${FULLNODE_URL} CLOCK=${CLOCK} (SUI_PRIVATE_KEY set? ${PRIVATE_KEY_HEX ? "yes" : "no"})`
  );
}

const client = new SuiClient({ url: FULLNODE_URL });

function hexToBytes(hex) {
  const s = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (s.length % 2 !== 0) throw new Error("Invalid hex");
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function loadKeypairFromEnv(secret) {
  const raw = secret.trim();
  // 1) Handle bech32: suiprivkey1... (older SDKs don't decode this)
  if (raw.startsWith("suiprivkey1")) {
    const { words } = bech32.decode(raw);
    const data = Buffer.from(bech32.fromWords(words));
    if (data.length < 33) {
      throw new Error("Invalid suiprivkey1 payload length");
    }
    const scheme = data[0];
    // 0x00 = ed25519
    if (scheme !== 0x00) throw new Error("Unsupported key scheme in suiprivkey");
    let secretKey = data.slice(1);
    // Some exports may include 64-byte expanded secret; trim to 32 bytes
    if (secretKey.length === 64) secretKey = secretKey.slice(0, 32);
    if (secretKey.length !== 32) throw new Error("Invalid ed25519 secret key length");
    return Ed25519Keypair.fromSecretKey(secretKey);
  }

  // 2) Try standard Sui export: ed25519:<base64>
  try {
    const { schema, secretKey } = decodeSuiPrivateKey(raw);
    if (schema !== "ed25519") throw new Error("Unsupported key scheme");
    return Ed25519Keypair.fromSecretKey(secretKey);
  } catch (_) {
    // 3) Fallback: hex (with or without 0x), 32 or 64 bytes
    let bytes = hexToBytes(raw);
    if (bytes.length === 64) {
      // Allow 64-byte expanded secret; use first 32 as seed
      bytes = bytes.slice(0, 32);
    }
    if (bytes.length !== 32)
      throw new Error(
        "SUI_PRIVATE_KEY must be 'suiprivkey1…', 'ed25519:<base64>', or 32/64 bytes hex"
      );
    return Ed25519Keypair.fromSecretKey(bytes);
  }
}

const keypair = PRIVATE_KEY_HEX ? loadKeypairFromEnv(PRIVATE_KEY_HEX) : null;

app.post("/api/request", async (req, res) => {
  try {
    if (!keypair) throw new Error("Server signer not configured");
    if (!isStablecoinMode) {
      const missing = [];
      if (!FAUCET_ID) missing.push("FAUCET_ID");
      if (!STABLECOIN_PACKAGE) missing.push("STABLECOIN_PACKAGE");
      if (!USDC_PACKAGE) missing.push("USDC_PACKAGE");
      if (!TREASURY) missing.push("TREASURY");
      // eslint-disable-next-line no-console
      console.warn("/api/request missing env:", missing, { mode: "stablecoin" });
      return res.status(500).json({
        error: "Faucet not configured",
        missing,
        cwd: process.cwd(),
        env: {
          FULLNODE_URL,
          CLOCK,
          MODE: isStablecoinMode ? "stablecoin" : "unconfigured",
          FAUCET_ID: FAUCET_ID?.slice(0, 10) + "...",
          STABLECOIN_PACKAGE: STABLECOIN_PACKAGE ? STABLECOIN_PACKAGE.slice(0, 10) + "..." : "",
          USDC_PACKAGE: USDC_PACKAGE ? USDC_PACKAGE.slice(0, 10) + "..." : "",
          TREASURY: TREASURY ? TREASURY.slice(0, 10) + "..." : "",
          SUI_PRIVATE_KEY: PRIVATE_KEY_HEX ? "set" : "missing",
        },
      });
    }

    const { recipient, amount } = req.body || {};
    if (
      typeof recipient !== "string" ||
      !recipient.startsWith("0x") ||
      recipient.length < 4
    ) {
      return res.status(400).send("Invalid recipient");
    }
    const amt = Number(amount);
    if (!Number.isFinite(amt) || amt <= 0) {
      return res.status(400).send("Invalid amount");
    }

    const tx = new Transaction();
    // Circle stablecoin faucet path (generic over T=USDC)
    tx.moveCall({
      target: `${STABLECOIN_PACKAGE}::faucet::request_for`,
      typeArguments: [`${USDC_PACKAGE}::usdc::USDC`],
      arguments: [
        tx.object(FAUCET_ID),
        tx.object(TREASURY),
        tx.pure.address(recipient),
        tx.pure.u64(amt),
        tx.object(CLOCK),
      ],
    });

    const result = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: tx,
    });

    return res.json({ digest: result.digest });
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
    return res.status(500).send(e?.message || "Server error");
  }
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Backend listening on http://localhost:${PORT}`);
});
