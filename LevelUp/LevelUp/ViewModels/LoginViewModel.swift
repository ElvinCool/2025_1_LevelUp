//
//  LoginViewModel.swift
//  LevelUp
//
//  Created by Ilya Ermakov on 11/19/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class LoginViewModel: ObservableObject {
    @Published var phone = ""
    @Published var password = ""
    @Published var showPassword = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    func login(completion: @escaping (Bool) -> Void) {
        guard !normalizedPhone.isEmpty, !password.isEmpty else {
            errorMessage = "Заполните все поля"
            showError = true
            completion(false)
            return
        }
        
        guard isPhoneValid else {
            errorMessage = "Введите корректный номер телефона"
            showError = true
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        let email = convertPhoneToEmail(normalizedPhone)
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = self.getErrorMessage(from: error)
                    self.showError = true
                    completion(false)
                } else if authResult != nil {
                    completion(true)
                } else {
                    self.errorMessage = "Неизвестная ошибка"
                    self.showError = true
                    completion(false)
                }
            }
        }
    }
    
    private var normalizedPhone: String {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        var digits = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        if digits.count == 10 {
            digits = "7" + digits
        } else if digits.count == 11, digits.first == "8" {
            digits.removeFirst()
            digits = "7" + digits
        }
        
        return digits
    }
    
    private var isPhoneValid: Bool {
        normalizedPhone.count == 11
    }
    
    private func convertPhoneToEmail(_ phone: String) -> String {
        "\(phone)@levelup.app"
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let authError = error as NSError? {
            switch authError.code {
            case AuthErrorCode.userNotFound.rawValue:
                return "Пользователь не найден"
            case AuthErrorCode.wrongPassword.rawValue:
                return "Неверный пароль"
            case AuthErrorCode.invalidEmail.rawValue:
                return "Неверный формат телефона"
            case AuthErrorCode.userDisabled.rawValue:
                return "Аккаунт заблокирован"
            case AuthErrorCode.networkError.rawValue:
                return "Ошибка сети. Проверьте подключение"
            case AuthErrorCode.tooManyRequests.rawValue:
                return "Слишком много попыток. Попробуйте позже"
            case AuthErrorCode.invalidCredential.rawValue:
                return "Неверный телефон или пароль"
            default:
                return "Ошибка авторизации. Попробуйте позже"
            }
        }
        return "Ошибка авторизации. Попробуйте позже"
    }
    
    var isFormValid: Bool {
        !normalizedPhone.isEmpty && isPhoneValid && !password.isEmpty
    }
}
