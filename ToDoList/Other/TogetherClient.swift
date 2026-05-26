//
//  LlamaAPIClient.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 17.03.2025.
//

import Foundation

// Define the structures for the API request and response
struct Message: Codable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

class TogetherClient {
    private let apiKey: String
    private let baseURL = "https://api.together.xyz/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func createChatCompletion(model: String, messages: [Message], completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        
        let request = ChatCompletionRequest(model: model, messages: messages)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                if let content = response.choices.first?.message.content {
                    completion(.success(content))
                } else {
                    completion(.failure(NSError(domain: "No content found in response", code: 0)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}
