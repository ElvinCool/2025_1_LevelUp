//
//  RegisterViewModel.swift
//  LevelUp
//
//  Created by Ilya Ermakov on 11/19/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class RegisterViewModel: ObservableObject {
    @Published var name = ""
    @Published var phone = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var showPassword = false
    @Published var showConfirmPassword = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    func togglePasswordVisibility() {
        showPassword.toggle()
    }
    
    func toggleConfirmPasswordVisibility() {
        showConfirmPassword.toggle()
    }
    
    func register(completion: @escaping (Bool) -> Void) {
        guard !trimmedName.isEmpty,
              !normalizedPhone.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else {
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
        
        guard passwordsMatch else {
            errorMessage = "Пароли не совпадают"
            showError = true
            completion(false)
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Пароль должен содержать минимум 6 символов"
            showError = true
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        showError = false
        
        let email = makeEmail(from: normalizedPhone)
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = self.getErrorMessage(from: error)
                    self.showError = true
                    completion(false)
                    return
                }
                
                guard let user = authResult?.user else {
                    self.errorMessage = "Не удалось создать аккаунт. Попробуйте еще раз"
                    self.showError = true
                    completion(false)
                    return
                }
                
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = self.trimmedName
                changeRequest.commitChanges { profileError in
                    DispatchQueue.main.async {
                        if let profileError = profileError {
                            print("Ошибка при обновлении профиля: \(profileError.localizedDescription)")
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    private func makeEmail(from phone: String) -> String {
        "\(phone)@levelup.app"
    }
    
    private func getErrorMessage(from error: Error) -> String {
        guard let authError = error as NSError? else {
            return "Не удалось зарегистрироваться. Попробуйте позже"
        }
        
        switch authError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "Аккаунт с таким телефоном уже существует"
        case AuthErrorCode.invalidEmail.rawValue:
            return "Введите корректный номер телефона"
        case AuthErrorCode.weakPassword.rawValue:
            return "Пароль слишком слабый"
        case AuthErrorCode.networkError.rawValue:
            return "Проблемы с сетью. Проверьте подключение"
        case AuthErrorCode.operationNotAllowed.rawValue:
            return "Регистрация временно недоступна"
        case AuthErrorCode.invalidCredential.rawValue:
            return "Неверный телефон или пароль"
        default:
            return "Не удалось зарегистрироваться. Попробуйте позже"
        }
    }
    
    var isFormValid: Bool {
        !trimmedName.isEmpty &&
        isPhoneValid &&
        password.count >= 6 &&
        passwordsMatch
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword
    }
}

