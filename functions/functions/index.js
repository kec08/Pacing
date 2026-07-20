const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

setGlobalOptions({ maxInstances: 10, region: "asia-northeast3" });

admin.initializeApp();

const firestore = admin.firestore();
const realtimeDatabase = admin.database();

async function deleteFirestoreDocuments(documents) {
  const chunks = [];
  for (let index = 0; index < documents.length; index += 400) {
    chunks.push(documents.slice(index, index + 400));
  }

  await Promise.all(chunks.map(async (documentsChunk) => {
    const batch = firestore.batch();
    documentsChunk.forEach((document) => batch.delete(document.ref));
    await batch.commit();
  }));
}

async function deleteListenSessionsForUser(uid) {
  const sessionsRef = realtimeDatabase.ref("listenSessions");
  const [hostSnapshot, guestSnapshot] = await Promise.all([
    sessionsRef.orderByChild("hostUID").equalTo(uid).once("value"),
    sessionsRef.orderByChild("guestUID").equalTo(uid).once("value"),
  ]);

  const sessions = new Map();
  [hostSnapshot, guestSnapshot].forEach((snapshot) => {
    snapshot.forEach((child) => sessions.set(child.key, child.val()));
  });

  const updates = {
    [`activeRunners/${uid}`]: null,
    [`incomingRequests/${uid}`]: null,
  };

  sessions.forEach((session, sessionID) => {
    updates[`listenSessions/${sessionID}`] = null;
    if (session.guestUID) {
      updates[`incomingRequests/${session.guestUID}/${sessionID}`] = null;
    }
  });

  await realtimeDatabase.ref().update(updates);
}

/**
 * Permanently deletes the authenticated user's Pacing account and all Pacing data.
 * OAuth provider accounts (Apple, Google, Kakao, Naver) are not affected.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인한 사용자만 계정을 삭제할 수 있어요.");
  }

  try {
    const userRef = firestore.collection("users").doc(uid);
    const [sentRequests, receivedRequests, ownedPlaylists, friendReferences] = await Promise.all([
      firestore.collection("friendRequests").where("fromUID", "==", uid).get(),
      firestore.collection("friendRequests").where("toUID", "==", uid).get(),
      firestore.collection("sharedPlaylists").where("ownerUID", "==", uid).get(),
      firestore.collectionGroup("friends")
        .where(admin.firestore.FieldPath.documentId(), "==", uid)
        .get(),
    ]);

    const externalDocuments = new Map();
    [sentRequests, receivedRequests, ownedPlaylists, friendReferences].forEach((snapshot) => {
      snapshot.docs.forEach((document) => externalDocuments.set(document.ref.path, document));
    });

    await Promise.all([
      deleteFirestoreDocuments([...externalDocuments.values()]),
      deleteListenSessionsForUser(uid),
    ]);

    await firestore.recursiveDelete(userRef);
    await admin.auth().deleteUser(uid);
    logger.info("Pacing account deleted", { uid });
    return { deleted: true };
  } catch (error) {
    logger.error("Pacing account deletion failed", { uid, error });
    throw new HttpsError("internal", "계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.");
  }
});

exports.naverLogin = onCall(async (request) => {
  logger.info("naverLogin called");

  const { code, state } = request.data;
  if (!code || !state) {
    throw new HttpsError("invalid-argument", "code와 state가 필요해요.");
  }

  // 인증 코드 → 액세스 토큰 교환
  let accessToken;
  try {
    const tokenRes = await axios.get("https://nid.naver.com/oauth2.0/token", {
      params: {
        grant_type: "authorization_code",
        client_id: "hxrh7_6fG3iRc6tKxOuY",
        client_secret: "l6C67zJ5g2",
        code,
        state,
        redirect_uri: "https://pacing-a8639.web.app/naver-callback",
      },
    });
    accessToken = tokenRes.data.access_token;
    if (!accessToken) throw new Error("access_token 없음");
    logger.info("Naver token obtained");
  } catch (e) {
    logger.error("Naver token error:", e.response?.data || e.message);
    throw new HttpsError("unauthenticated", "네이버 인증 코드가 유효하지 않아요.");
  }

  // 사용자 정보 조회
  let naverUser;
  try {
    const userRes = await axios.get("https://openapi.naver.com/v1/nid/me", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    naverUser = userRes.data.response;
    logger.info("Naver user id:", naverUser.id);
  } catch (e) {
    logger.error("Naver user API error:", e.response?.data || e.message);
    throw new HttpsError("unauthenticated", "네이버 사용자 정보를 가져오지 못했어요.");
  }

  const naverUID = `naver:${naverUser.id}`;
  const nickname = naverUser.nickname ?? naverUser.name ?? "러너";
  const profileImage = naverUser.profile_image ?? null;

  try {
    const customToken = await admin.auth().createCustomToken(naverUID, {
      provider: "naver",
      nickname,
      profileImage,
    });
    logger.info("Custom token created for:", naverUID);
    return { customToken, nickname, profileImage };
  } catch (e) {
    logger.error("Custom token error:", e.message);
    throw new HttpsError("internal", "Custom Token 생성에 실패했어요.");
  }
});

exports.kakaoLogin = onCall(async (request) => {
  logger.info("kakaoLogin called");

  const accessToken = request.data.accessToken;
  if (!accessToken) {
    logger.error("accessToken missing");
    throw new HttpsError("invalid-argument", "accessToken이 필요해요.");
  }

  logger.info("Calling Kakao API with token length:", accessToken.length);

  // 카카오 사용자 정보 조회
  let kakaoUser;
  try {
    const response = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
      },
    });
    kakaoUser = response.data;
    logger.info("Kakao user id:", kakaoUser.id);
  } catch (e) {
    logger.error("Kakao API error:", e.response?.data || e.message);
    throw new HttpsError("unauthenticated", "카카오 토큰이 유효하지 않아요.");
  }

  const kakaoUID = `kakao:${kakaoUser.id}`;
  const nickname = kakaoUser.kakao_account?.profile?.nickname ?? "러너";
  const profileImage = kakaoUser.kakao_account?.profile?.profile_image_url ?? null;

  logger.info("Creating custom token for:", kakaoUID);

  // Firebase Custom Token 발급
  try {
    const customToken = await admin.auth().createCustomToken(kakaoUID, {
      provider: "kakao",
      nickname,
      profileImage,
    });
    logger.info("Custom token created successfully");
    return { customToken, nickname, profileImage };
  } catch (e) {
    logger.error("Custom token error:", e.message);
    throw new HttpsError("internal", "Custom Token 생성에 실패했어요.");
  }
});
