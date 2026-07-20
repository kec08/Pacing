import Foundation

enum AuthInputValidator {
    static func emailError(for email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return "이메일을 입력해주세요." }

        let expression = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        guard trimmedEmail.range(of: expression, options: .regularExpression) != nil else {
            return "올바른 이메일 주소를 입력해주세요."
        }
        return nil
    }

    static func passwordError(for password: String) -> String? {
        guard !password.isEmpty else { return "비밀번호를 입력해주세요." }
        guard password.count >= 8 else { return "비밀번호는 8자 이상으로 입력해주세요." }
        return nil
    }

    static func signUpError(email: String, password: String, confirmation: String) -> String? {
        if let emailError = emailError(for: email) { return emailError }
        if let passwordError = passwordError(for: password) { return passwordError }
        guard password == confirmation else { return "비밀번호가 일치하지 않아요." }
        return nil
    }
}
