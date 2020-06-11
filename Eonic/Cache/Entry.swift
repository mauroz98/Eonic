//
//  Entry.swift
//  Colonnine
//
//  Created by Yuri Spaziani on 20/02/2020.
//  Copyright © 2020 Antonio Ferraioli. All rights reserved.
//

import Foundation

extension Cache {
    final class Entry{
        let key: Key
        let value: Value
        let expirationDate: Date

        init(key: Key, value: Value, expirationDate: Date) {
            self.key = key
            self.value = value
            self.expirationDate = expirationDate
        }
    }
}

extension Cache.Entry: Codable where Key: Codable, Value: Codable {}
