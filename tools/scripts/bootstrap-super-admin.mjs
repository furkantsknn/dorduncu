/**
 * Tek seferlik ilk super_admin bootstrap.
 * Çalıştıktan sonra bu dosyayı sil.
 *
 * Yalnızca --uid ile verilen tek hesaba yazar.
 * Başka bir super_admin varsa hiçbir şey yazmaz.
 * setUserRole ile aynı claim ve users/{uid} ayna alanlarını kullanır.
 */

import {createRequire} from "node:module";
import path from "node:path";
import {fileURLToPath} from "node:url";
import readline from "node:readline/promises";
import {stdin as input, stdout as output} from "node:process";

const projectId = "dorduncu-8e599";
const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const functionsDir = path.resolve(scriptDir, "../../functions");
const require = createRequire(path.join(functionsDir, "package.json"));

const {initializeApp, getApps} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

const uidPattern = /^[A-Za-z0-9_-]{8,128}$/;

function fail(message) {
  console.error(message);
  process.exit(1);
}

function readTargetUid(argv) {
  const args = argv.slice(2);

  if (args.length !== 2 || args[0] !== "--uid") {
    fail(
      "Kullanım: node .\\tools\\scripts\\bootstrap-super-admin.mjs --uid <UID>",
    );
  }

  const uid = args[1];

  if (typeof uid !== "string" || !uidPattern.test(uid)) {
    fail("UID tek bir hesap kimliği olmalı. Liste, boşluk veya joker kabul edilmez.");
  }

  return uid;
}

function claimRole(user) {
  const role = user.customClaims?.role;
  return typeof role === "string" ? role : "";
}

async function authUserExists(auth, uid) {
  try {
    await auth.getUser(uid);
    return true;
  } catch (error) {
    if (error?.code === "auth/user-not-found") {
      return false;
    }

    throw error;
  }
}

async function findOtherSuperAdmins(auth, firestore, targetUid) {
  const found = new Set();

  let pageToken;

  do {
    const page = await auth.listUsers(1000, pageToken);

    for (const user of page.users) {
      if (user.uid !== targetUid && claimRole(user) === "super_admin") {
        found.add(user.uid);
      }
    }

    pageToken = page.pageToken;
  } while (pageToken);

  const mirrored = await firestore
    .collection("users")
    .where("role", "==", "super_admin")
    .get();

  for (const document of mirrored.docs) {
    if (document.id === targetUid || found.has(document.id)) {
      continue;
    }

    const stillInAuth = await authUserExists(auth, document.id);

    if (!stillInAuth) {
      console.log(
        `Yok sayıldı: ${document.id} Auth'ta yok, Firestore rolü eski.`,
      );
      continue;
    }

    found.add(document.id);
  }

  return [...found];
}

function describeAccount(user, userDocumentExists) {
  const providers = user.providerData.map((provider) => provider.providerId);
  const email = user.email ?? "(yok)";
  const phone = user.phoneNumber ?? "(yok)";
  const passwordProvider = providers.includes("password");
  const panelReady = Boolean(user.email) &&
    user.emailVerified === true &&
    passwordProvider;

  console.log("");
  console.log(`Proje: ${projectId}`);
  console.log(`UID: ${user.uid}`);
  console.log(`E-posta: ${email}`);
  console.log(`E-posta doğrulandı: ${user.emailVerified ? "evet" : "hayır"}`);
  console.log(`Telefon: ${phone}`);
  console.log(`Sağlayıcılar: ${providers.length ? providers.join(", ") : "(yok)"}`);
  console.log(
    `users belgesi: ${userDocumentExists ? "var" : "yok, yalnızca rol alanları yazılacak"}`,
  );

  if (!panelReady) {
    console.log("");
    console.log(
      "Uyarı: Bu hesap doğrulanmış e-posta/parola hesabı değil. " +
      "Admin paneli e-posta, parola ve SMS MFA ile açılır. " +
      "Claim yine de yalnızca bu UID'ye yazılır.",
    );
  }

  console.log("");
}

async function confirmUid(uid) {
  if (!input.isTTY) {
    fail("Onay yalnızca etkileşimli terminalde verilebilir.");
  }

  const prompt = readline.createInterface({input, output});

  try {
    const answer = (await prompt.question(
      "Yalnızca bu UID yazılacak. Devam etmek için UID'yi aynen yazın: ",
    )).trim();

    if (answer !== uid) {
      fail("Onay UID'si eşleşmedi. Hiçbir kayıt değiştirilmedi.");
    }
  } finally {
    prompt.close();
  }
}

async function main() {
  const uid = readTargetUid(process.argv);

  const app = getApps().length === 0 ?
    initializeApp({projectId}) :
    getApps()[0];
  const auth = getAuth(app);
  const firestore = getFirestore(app);

  let user;

  try {
    user = await auth.getUser(uid);
  } catch (error) {
    const code = error?.code ?? "";

    if (code === "auth/user-not-found") {
      fail(`Auth kullanıcısı bulunamadı: ${uid}`);
    }

    if (code === "app/invalid-credential" || code === "auth/invalid-credential") {
      fail(
        "Application Default Credentials geçersiz. " +
        "Yeni anahtar oluşturma. Mevcut gcloud oturumu için " +
        "gcloud auth application-default login kullan.",
      );
    }

    throw error;
  }

  const userRef = firestore.collection("users").doc(uid);
  const userSnapshot = await userRef.get();
  const alreadySuperAdmin = claimRole(user) === "super_admin" ||
    userSnapshot.data()?.role === "super_admin";

  if (alreadySuperAdmin) {
    fail("Bu hesap zaten super_admin. Değişiklik yapılmadı.");
  }

  const others = await findOtherSuperAdmins(auth, firestore, uid);

  if (others.length > 0) {
    fail(
      "Başka bir super_admin var. Bu script ikinci hesap açmaz. " +
      "Sonraki roller için setUserRole kullan. " +
      `Mevcut UID: ${others.join(", ")}`,
    );
  }

  describeAccount(user, userSnapshot.exists);
  await confirmUid(uid);

  const othersAfterConfirm = await findOtherSuperAdmins(auth, firestore, uid);

  if (othersAfterConfirm.length > 0) {
    fail("Onay sırasında başka bir super_admin oluştu. Yazım iptal edildi.");
  }

  const existingClaims = user.customClaims ?? {};
  const previousRole = typeof existingClaims.role === "string" ?
    existingClaims.role :
    (userSnapshot.data()?.role ?? "user");
  const claims = {
    ...existingClaims,
    admin: true,
    adminPanel: true,
    moderator: false,
    role: "super_admin",
  };
  const now = new Date();

  await auth.setCustomUserClaims(uid, claims);

  try {
    await userRef.set(
      {
        role: "super_admin",
        admin: true,
        adminPanel: true,
        roleUpdatedAt: now,
        roleUpdatedBy: "bootstrap",
        updatedAt: now,
      },
      {merge: true},
    );
  } catch (error) {
    await auth.setCustomUserClaims(uid, existingClaims);
    throw error;
  }

  await auth.revokeRefreshTokens(uid);

  await firestore.collection("audit_logs").add({
    action: "setUserRole",
    performedBy: "bootstrap",
    targetUid: uid,
    metadata: {
      previousRole,
      role: "super_admin",
      reason: "Initial super_admin bootstrap",
      performedByRole: "bootstrap",
      targetSessionsRevoked: true,
      bootstrap: true,
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log(`super_admin yazıldı: ${uid}`);
  console.log("Oturumlar kapatıldı. Bu scripti bootstrap sonrası sil.");
}

main().catch((error) => {
  console.error(error?.message ?? error);
  process.exit(1);
});
