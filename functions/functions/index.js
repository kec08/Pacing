const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

setGlobalOptions({ maxInstances: 10, region: "asia-northeast3" });

admin.initializeApp();

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

