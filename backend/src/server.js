import "dotenv/config";
import express from "express";
import cors from "cors";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/cryptography";
import { Transaction } from "@mysten/sui/transactions";

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
const FAUCET_PACKAGE = process.env.FAUCET_PACKAGE || "";
const FAUCET_ID = process.env.FAUCET_ID || "";
const CLOCK = process.env.CLOCK || "0x6";
const PRIVATE_KEY_HEX = process.env.SUI_PRIVATE_KEY || "";

if (!FAUCET_PACKAGE || !FAUCET_ID || !PRIVATE_KEY_HEX) {
  // eslint-disable-next-line no-console
  console.warn("Missing env: FAUCET_PACKAGE, FAUCET_ID, or SUI_PRIVATE_KEY");
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

function loadKeypairFromHex(secretHex) {
  let bytes = hexToBytes(secretHex.trim());
  if (bytes.length === 64) {
    // Allow 64-byte expanded secret; use first 32 as seed
    bytes = bytes.slice(0, 32);
  }
  if (bytes.length !== 32)
    throw new Error("SUI_PRIVATE_KEY must be 32 or 64 bytes hex");
  return Ed25519Keypair.fromSecretKey(bytes);
}

const keypair = PRIVATE_KEY_HEX ? loadKeypairFromHex(PRIVATE_KEY_HEX) : null;

app.post("/api/request", async (req, res) => {
  try {
    if (!keypair) throw new Error("Server signer not configured");
    if (!FAUCET_PACKAGE || !FAUCET_ID) throw new Error("Faucet not configured");

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
    tx.moveCall({
      target: `${FAUCET_PACKAGE}::faucet::request_tokens_for`,
      arguments: [
        tx.object(FAUCET_ID),
        // Address argument
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
