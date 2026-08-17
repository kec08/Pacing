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
    // 탈퇴 사용자의 수신함은 위에서 전체 삭제하므로 하위 경로를 함께 넣지 않는다.
    if (session.guestUID && session.guestUID !== uid) {
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
    const [sentRequests, receivedRequests, ownedPlaylists, ownFriends] = await Promise.all([
      firestore.collection("friendRequests").where("fromUID", "==", uid).get(),
      firestore.collection("friendRequests").where("toUID", "==", uid).get(),
      firestore.collection("sharedPlaylists").where("ownerUID", "==", uid).get(),
      userRef.collection("friends").get(),
    ]);

    const externalDocuments = new Map();
    [sentRequests, receivedRequests, ownedPlaylists].forEach((snapshot) => {
      snapshot.docs.forEach((document) => externalDocuments.set(document.ref.path, document));
    });
    ownFriends.docs.forEach((friend) => {
      const reciprocalFriendRef = firestore.collection("users")
        .doc(friend.id)
        .collection("friends")
        .doc(uid);
      externalDocuments.set(reciprocalFriendRef.path, { ref: reciprocalFriendRef });
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
    logger.error("Pacing account deletion failed", {
      uid,
      errorCode: error?.code,
      errorMessage: error?.message,
      errorStack: error?.stack,
    });
    throw new HttpsError("internal", "계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.");
  }
});

/**
 * Accepts an incoming friend request and creates the reciprocal friend records.
 * Admin SDK writes bypass client rules so a recipient cannot forge access to a
 * different user's friend list from the iOS client.
 */
exports.acceptFriendRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  const requestID = request.data?.requestID;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인한 사용자만 친구 요청을 수락할 수 있어요.");
  }
  if (!requestID || typeof requestID !== "string") {
    throw new HttpsError("invalid-argument", "친구 요청 ID가 필요해요.");
  }

  const requestRef = firestore.collection("friendRequests").doc(requestID);
  const friendProfile = (user, fallbackNickname) => ({
    uid: user.id,
    nickname: user.get("nickname") || fallbackNickname,
    statusText: "최근 활동 없음",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(user.get("profileImageBase64") ? { profileImageBase64: user.get("profileImageBase64") } : {}),
  });

  try {
    const result = await firestore.runTransaction(async (transaction) => {
      const friendRequest = await transaction.get(requestRef);
      if (!friendRequest.exists) {
        throw new HttpsError("not-found", "친구 요청을 찾을 수 없어요.");
      }

      const data = friendRequest.data();
      if (data.toUID !== uid) {
        throw new HttpsError("permission-denied", "수락할 수 없는 친구 요청이에요.");
      }
      // 사용자가 수락 버튼을 연속 탭하거나 네트워크가 재시도해도, 이미 완료된
      // 동일 요청은 실패가 아닌 성공으로 응답한다. 트랜잭션이 친구 문서와 상태를
      // 함께 기록하므로 accepted 상태는 상호 친구 관계가 완성된 상태를 뜻한다.
      if (data.status === "accepted") {
        return { accepted: true, alreadyAccepted: true };
      }
      if (data.status !== "pending" || typeof data.fromUID !== "string" || !data.fromUID) {
        throw new HttpsError("failed-precondition", "처리할 수 없는 친구 요청이에요.");
      }

      const senderRef = firestore.collection("users").doc(data.fromUID);
      const recipientRef = firestore.collection("users").doc(uid);
      const [sender, recipient] = await transaction.getAll(senderRef, recipientRef);

      transaction.set(
        recipientRef.collection("friends").doc(data.fromUID),
        friendProfile(sender, "러너"),
        { merge: true },
      );
      transaction.set(
        senderRef.collection("friends").doc(uid),
        friendProfile(recipient, "러너"),
        { merge: true },
      );
      transaction.update(requestRef, { status: "accepted" });
      return { accepted: true, alreadyAccepted: false };
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Friend request acceptance failed", {
      uid,
      requestID,
      errorCode: error?.code,
      errorMessage: error?.message,
    });
    throw new HttpsError("internal", "친구 요청을 수락하지 못했어요. 잠시 후 다시 시도해 주세요.");
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
